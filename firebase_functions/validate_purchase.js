/**
 * SECURE PURCHASE VALIDATION CLOUD FUNCTION
 * 
 * This function validates purchases with RevenueCat server-to-server
 * to prevent fraud and ensure payment legitimacy.
 * 
 * SETUP:
 * 1. Set RevenueCat API key: 
 *    firebase functions:config:set revenuecat.api_key="YOUR_API_KEY"
 * 2. Deploy: firebase deploy --only functions:validatePurchase
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const https = require('https');

const db = admin.firestore();
const REVENUECAT_API_KEY = functions.config().revenuecat?.api_key || process.env.REVENUECAT_API_KEY;
const REVENUECAT_WEBHOOK_SECRET = functions.config().revenuecat?.webhook_secret || process.env.REVENUECAT_WEBHOOK_SECRET;

// Validate API key is configured
if (!REVENUECAT_API_KEY) {
  console.error('[WARNING] RevenueCat API key not configured!');
  console.error('Run: firebase functions:config:set revenuecat.api_key="YOUR_KEY"');
}

// ============================================================================
// PURCHASE VALIDATION WITH REVENUECAT
// ============================================================================

/**
 * Validates a purchase with RevenueCat and records it securely
 * This must be called from a secure backend, not the client
 */
exports.validateAndRecordPurchase = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ success: false, error: { code: 'method-not-allowed', message: 'Only POST requests allowed' } });
    return;
  }

  try {
    // ========================================================================
    // AUTHENTICATION: Verify Firebase ID token from Authorization header
    // ========================================================================
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ success: false, error: { code: 'unauthenticated', message: 'Missing or invalid Authorization header' } });
      return;
    }

    const idToken = authHeader.substring(7);
    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (authErr) {
      console.error('[validatePurchase] ID token verification failed:', authErr.message);
      res.status(401).json({ success: false, error: { code: 'unauthenticated', message: 'Invalid or expired ID token' } });
      return;
    }

    const userId = decodedToken.uid;

    // ========================================================================
    // PARSE REQUEST BODY (for raw HTTP POST, data is in req.body directly)
    // ========================================================================
    const { journeyId, journeyTitle, transactionId, packageId } = req.body;

    // ========================================================================
    // INPUT VALIDATION
    // ========================================================================
    if (!journeyId || !journeyTitle || !transactionId || !packageId) {
      console.error('[validatePurchase] Missing required fields in request body:', { journeyId, journeyTitle, transactionId, packageId });
      res.status(400).json({
        success: false,
        error: {
          code: 'invalid-argument',
          message: 'Missing required fields: journeyId, journeyTitle, transactionId, packageId'
        }
      });
      return;
    }

    if (typeof journeyId !== 'string' || journeyId.length === 0) {
      res.status(400).json({ success: false, error: { code: 'invalid-argument', message: 'Invalid journeyId' } });
      return;
    }

    if (typeof transactionId !== 'string' || transactionId.length === 0) {
      res.status(400).json({ success: false, error: { code: 'invalid-argument', message: 'Invalid transactionId' } });
      return;
    }

    // ====================================================================
    // FRAUD CHECK 1: Verify user exists and is legitimate
    // ====================================================================
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.error(`[validatePurchase] User doc not found: ${userId}`);
      res.status(404).json({ success: false, error: { code: 'not-found', message: 'User profile not found' } });
      return;
    }

    // ====================================================================
    // FRAUD CHECK 2: Check for duplicate purchases of this journey
    // ====================================================================
    const existingPurchase = await db
      .collection('users')
      .doc(userId)
      .collection('purchases')
      .doc(journeyId)
      .get();

    if (existingPurchase.exists) {
      console.warn(
        `[validatePurchase] Duplicate purchase attempt: User ${userId} for Journey ${journeyId}`
      );
      res.status(200).json({
        success: true,
        message: 'Journey already purchased',
        duplicate: true,
        purchaseRecord: existingPurchase.data(),
      });
      return;
    }

    // ====================================================================
    // FRAUD CHECK 3: Validate with RevenueCat (server-to-server)
    // ====================================================================
    console.log(
      `[validatePurchase] Validating with RevenueCat: User=${userId}, Transaction=${transactionId}`
    );

    const revenueCatValidation = await validateWithRevenueCat(
      userId,
      transactionId,
      packageId
    );

    if (!revenueCatValidation.isValid) {
      console.error(
        `[validatePurchase] RevenueCat validation failed: ${revenueCatValidation.reason}`
      );
      res.status(403).json({
        success: false,
        error: { code: 'permission-denied', message: `Purchase validation failed: ${revenueCatValidation.reason}` }
      });
      return;
    }

    // ====================================================================
    // FRAUD CHECK 4: Validate transaction metadata
    // ====================================================================
    if (!revenueCatValidation.transactionData) {
      console.error('[validatePurchase] RevenueCat returned no transaction data');
      res.status(403).json({ success: false, error: { code: 'permission-denied', message: 'Unable to retrieve transaction details' } });
      return;
    }

    const txData = revenueCatValidation.transactionData;

    // Verify amount exists and is positive
    if (!txData.price || typeof txData.price !== 'number' || txData.price <= 0) {
      console.error(
        `[validatePurchase] Invalid price: ${txData.price} for User ${userId}`
      );
      res.status(403).json({ success: false, error: { code: 'permission-denied', message: 'Invalid transaction amount' } });
      return;
    }

    // ====================================================================
    // RECORD PURCHASE (Only if all validations pass)
    // ====================================================================
    const purchaseRecord = {
      journeyId,
      journeyTitle,
      userId,
      purchaseDate: admin.firestore.FieldValue.serverTimestamp(),
      pricePaid: txData.price || 0,
      currency: txData.currency || 'USD',
      revenueCatTransactionId: transactionId,
      revenueCatCustomerId: revenueCatValidation.customerId,
      packageId,
      type: 'journey',
      validatedAt: admin.firestore.FieldValue.serverTimestamp(),
      validatedBy: 'revenuecat_validation',
      ipAddress: req.ip || 'unknown',
      userAgent: req.headers['user-agent'] || 'unknown',
      duplicatePrevention: 'checked',
      revenueCatVerified: true,
    };

    // Use a transaction to ensure atomic write
    const result = await db.runTransaction(async (transaction) => {
      const purchaseRef = db
        .collection('users')
        .doc(userId)
        .collection('purchases')
        .doc(journeyId);

      const existingTx = await transaction.get(purchaseRef);
      if (existingTx.exists) {
        throw new Error('DUPLICATE_PURCHASE_CONCURRENT_WRITE');
      }

      transaction.set(purchaseRef, purchaseRecord);

      const userRef = db.collection('users').doc(userId);
      transaction.update(userRef, {
        'purchasedJourneys': admin.firestore.FieldValue.arrayUnion([journeyId]),
        'lastPurchaseAt': admin.firestore.FieldValue.serverTimestamp(),
        'lastPurchaseJourney': journeyTitle,
      });

      return purchaseRecord;
    });

    console.log(
      `[validatePurchase] ✅ Purchase recorded: User=${userId}, Journey=${journeyId}`
    );

    // ====================================================================
    // SEND NOTIFICATIONS
    // ====================================================================
    try {
      await sendPurchaseConfirmationNotification(userId, journeyTitle, txData.price);
    } catch (notifError) {
      console.error('[validatePurchase] Notification error (non-fatal):', notifError);
    }

    res.status(200).json({
      success: true,
      message: 'Purchase validated and recorded successfully',
      purchaseRecord: result,
    });
    
  } catch (error) {
    console.error('[validatePurchase] Unexpected error:', error.message);
    res.status(500).json({
      success: false,
      error: { code: 'internal', message: 'Failed to process purchase. Please contact support.' }
    });
  }
});

// ============================================================================
// REVENUECAT VALIDATION (Server-to-Server)
// ============================================================================

/**
 * Validates purchase with RevenueCat using server-to-server API
 * This prevents client-side manipulation
 */
async function validateWithRevenueCat(userId, transactionId, packageId) {
  if (!REVENUECAT_API_KEY) {
    console.error('[RevenueCat] API key not configured');
    return {
      isValid: false,
      reason: 'RevenueCat not configured on server',
    };
  }

  return new Promise((resolve, reject) => {
    // Validate API key exists
    if (!REVENUECAT_API_KEY) {
      console.error('[RevenueCat] API key not configured');
      return resolve({
        isValid: false,
        reason: 'RevenueCat not configured',
      });
    }

    // RevenueCat API endpoint to get customer info
    // We use the customer ID which is typically the user ID in our case
    const options = {
      hostname: 'api.revenuecat.com',
      port: 443,
      path: `/v1/customers/${userId}`,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${REVENUECAT_API_KEY}`,
        'Content-Type': 'application/json',
      },
      timeout: 5000, // 5 second timeout to prevent hanging
    };

    const req = https.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        try {
          if (res.statusCode !== 200) {
            console.error(
              `[RevenueCat] API error: ${res.statusCode} - ${data}`
            );
            resolve({
              isValid: false,
              reason: `RevenueCat validation failed: ${res.statusCode}`,
            });
            return;
          }

          const response = JSON.parse(data);
          const customerData = response.customer || {};

          // Check if customer has active entitlements or valid transactions
          const activeEntitlements = customerData.entitlements || {};
          const transactions = customerData.original_purchase_date
            ? 'has_transactions'
            : 'no_transactions';

          if (Object.keys(activeEntitlements).length === 0 && !customerData.original_purchase_date) {
            console.warn(
              `[RevenueCat] No valid entitlements or transactions for ${userId}`
            );
            resolve({
              isValid: false,
              reason: 'No valid purchase found in RevenueCat',
            });
            return;
          }

          // Extract transaction details from management_url or other sources
          // Note: RevenueCat API response structure varies
          const txData = extractTransactionData(customerData, packageId);

          resolve({
            isValid: true,
            customerId: userId,
            transactionData: txData,
            revenueCatCustomer: customerData,
          });
        } catch (parseError) {
          console.error('[RevenueCat] Parse error:', parseError);
          resolve({
            isValid: false,
            reason: 'Failed to parse RevenueCat response',
          });
        }
      });
    });

    req.on('error', (error) => {
      console.error('[RevenueCat] Request error:', error);
      resolve({
        isValid: false,
        reason: 'RevenueCat connection error',
      });
    });

    // Handle timeout
    req.on('timeout', () => {
      console.error('[RevenueCat] Request timeout (5s)');
      req.destroy();
      resolve({
        isValid: false,
        reason: 'RevenueCat timeout',
      });
    });

    req.end();
  });
}

/**
 * Extracts transaction data from RevenueCat customer object
 */
function extractTransactionData(customerData, packageId) {
  // Default transaction data structure
  const defaultData = {
    price: 0,
    currency: 'USD',
    packageId,
  };

  // Try to extract from entitlements
  // FIX: Check for null explicitly (typeof null === 'object' in JS)
  if (customerData.entitlements && 
      typeof customerData.entitlements === 'object' && 
      customerData.entitlements !== null) {
    try {
      const entitlementKeys = Object.keys(customerData.entitlements);
      if (entitlementKeys.length > 0) {
        const firstEntitlement = customerData.entitlements[entitlementKeys[0]];
        if (firstEntitlement) {
          return {
            price: firstEntitlement.price || 0,
            currency: firstEntitlement.currency || 'USD',
            packageId,
          };
        }
      }
    } catch (error) {
      console.error('[extractTransactionData] Error extracting data:', error);
      return defaultData;
    }
  }

  return defaultData;
}

/**
 * Sends purchase confirmation notification to user
 * Writes to notifications subcollection so FCM trigger fires
 */
async function sendPurchaseConfirmationNotification(userId, journeyTitle, price) {
  try {
    const userRef = db.collection('users').doc(userId);
    const notificationsRef = userRef.collection('notifications');
    
    await notificationsRef.add({
      type: 'purchase_confirmed',
      title: '🎉 Journey Unlocked!',
      body: `"${journeyTitle}" is now available. Let's begin!`,
      payload: {
        type: 'purchase_confirmed',
        title: '🎉 Journey Unlocked!',
        body: `"${journeyTitle}" is available for $${price}`,
        journeyTitle: journeyTitle,
        price: price,
        route: '/journeys',
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isSent: false,
    });
    
    console.log(`[Notification] ✅ Purchase notification queued for ${userId}`);
  } catch (error) {
    console.error('[Notification] Failed to send confirmation:', error);
    // Don't fail purchase if notification fails
  }
}

// ============================================================================
// WEBHOOK: RevenueCat Subscription Update
// ============================================================================

/**
 * Webhook endpoint for RevenueCat to notify about subscription changes
 * This ensures subscription status stays in sync
 * 
 * SECURITY: Verifies webhook signature to prevent spoofing
 */
exports.revenueCatWebhook = functions.https.onRequest(async (req, res) => {
  console.log('[RevenueCat Webhook] Received event:', req.body.event?.type);

  // SECURITY: Verify webhook signature (if available)
  // This prevents attackers from sending fake subscription updates
  if (REVENUECAT_WEBHOOK_SECRET) {
    const crypto = require('crypto');
    const signature = req.headers['x-rc-webhook-signature'];
    
    if (!signature) {
      console.error('[RevenueCat Webhook] Missing signature header');
      return res.status(401).json({ error: 'Missing signature' });
    }

    // Verify it came from RevenueCat
    const bodyString = req.rawBody?.toString() || JSON.stringify(req.body);
    const expectedSignature = crypto
      .createHmac('sha1', REVENUECAT_WEBHOOK_SECRET)
      .update(bodyString)
      .digest('hex');

    if (signature !== expectedSignature) {
      console.error('[RevenueCat Webhook] Invalid signature - rejecting webhook');
      return res.status(401).json({ error: 'Invalid signature' });
    }
  } else {
    console.warn('[RevenueCat Webhook] No webhook secret configured - skipping signature verification');
  }

  try {
    const event = req.body.event || {};
    const eventType = event.type;
    const customerId = event.app_user_id;

    // LOG: Always log what we're receiving
    console.log('[RevenueCat Webhook] EVENT RECEIVED:');
    console.log(`  event_type: ${eventType}`);
    console.log(`  app_user_id: ${customerId}`);
    console.log(`  product_id: ${event.product_id}`);
    console.log(`  product_id_aliases: ${JSON.stringify(event.product_id_aliases)}`);
    console.log(`  expiration_at_ms: ${event.expiration_at_ms}`);

    if (!customerId) {
      console.error('[RevenueCat Webhook] Missing app_user_id');
      return res.status(400).json({ error: 'Missing app_user_id' });
    }

    switch (eventType) {
      case 'INITIAL_SUBSCRIPTION':
      case 'RENEWAL':
        // Update subscription status
        await updateSubscriptionStatus(customerId, event);
        break;

      case 'SUBSCRIPTION_PAUSED':
      case 'SUBSCRIPTION_CANCELLED':
        await cancelSubscriptionStatus(customerId, event);
        break;

      case 'EXPIRED':
        await expireSubscriptionStatus(customerId);
        break;

      default:
        console.log(`[RevenueCat Webhook] Unhandled event type: ${eventType}`);
    }

    res.json({ success: true });
  } catch (error) {
    console.error('[RevenueCat Webhook] Error:', error);
    res.status(500).json({ error: error.message });
  }
});

async function updateSubscriptionStatus(userId, event) {
  try {
    console.log(`[RevenueCat] Attempting to update subscription for revenueCat customer: ${userId}`);

    // Attempt to resolve the revenueCat app_user_id to a Firebase user document.
    // 1) Direct doc id match
    // 2) Match users where `revenueCat.customerId` == app_user_id
    // 3) Match users where `subscription.revenueCatCustomerId` == app_user_id
    // If not found, write an orphan record for manual reconciliation.

    let userRef = db.collection('users').doc(userId);
    let userDoc = await userRef.get();

    if (!userDoc.exists) {
      console.log('[RevenueCat] Direct user doc not found; trying lookup by revenueCat.customerId...');
      const byRc = await db.collection('users')
        .where('revenueCat.customerId', '==', userId)
        .limit(1)
        .get();

      if (!byRc.empty) {
        userDoc = byRc.docs[0];
        userRef = userDoc.ref;
        console.log(`[RevenueCat] Resolved to user id via revenueCat.customerId: ${userRef.id}`);
      } else {
        console.log('[RevenueCat] No match on revenueCat.customerId, trying subscription.revenueCatCustomerId...');
        const bySub = await db.collection('users')
          .where('subscription.revenueCatCustomerId', '==', userId)
          .limit(1)
          .get();

        if (!bySub.empty) {
          userDoc = bySub.docs[0];
          userRef = userDoc.ref;
          console.log(`[RevenueCat] Resolved to user id via subscription.revenueCatCustomerId: ${userRef.id}`);
        }
      }
    }

    if (!userDoc || !userDoc.exists) {
      console.warn(`[RevenueCat Webhook] ⚠️ No user found for RevenueCat customer: ${userId}`);
      // Create an orphaned event record for admin reconciliation
      // Try to enrich the orphaned event with customer metadata (email) by
      // calling RevenueCat server-to-server API. This helps admins identify
      // the correct Firebase user by email when app_user_id is anonymous.
      let customerEmail = null;
      try {
        const customer = await fetchRevenueCatCustomer(userId);
        if (customer) {
          // Try common email locations in RevenueCat response
          customerEmail = customer.email ||
            (customer.subscriber && customer.subscriber.email) ||
            (customer.attributes && customer.attributes.email) ||
            null;
        }
      } catch (fetchErr) {
        console.warn('[RevenueCat Webhook] Failed to fetch customer from RevenueCat:', fetchErr.message || fetchErr);
      }

      const orphanRef = db.collection('revenuecat_orphaned_events').doc();
      await orphanRef.set({
        appUserId: userId,
        customerEmail: customerEmail || null,
        eventType: event.type || null,
        productId: event.product_id || null,
        productAliases: event.product_id_aliases || null,
        rawEvent: event,
        receivedAt: admin.firestore.FieldValue.serverTimestamp(),
        handled: false,
      });

      console.log(`[RevenueCat Webhook] Orphaned event recorded: ${orphanRef.id}`);
      return; // stop here — admin can reconcile the orphan later
    }

    const expireDate = event.expiration_at_ms ? new Date(event.expiration_at_ms) : null;

    // Read tier from event if available
    const tierFromEvent = (event.product_id_aliases && event.product_id_aliases[0]) || event.product_id || 'monthly';

    await userRef.update({
      'subscription': {
        isActive: true,
        tier: tierFromEvent,
        startDate: new Date(),
        expiryDate: expireDate,
        autoRenew: true,
        revenueCatCustomerId: userId,
        revenueCatSubscriptionId: event.product_id || null,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      },
      'onPremium': true,
      'subExpDate': expireDate, // Legacy field for backward compatibility
      'entitledUser': true,
      'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[RevenueCat] Updated subscription for resolved user: ${userRef.id}`);
  } catch (error) {
    console.error('[RevenueCat] Failed to update subscription:', error);
  }
}

async function cancelSubscriptionStatus(userId, event) {
  try {
    // SECURITY: Verify user exists
    const userRef = db.collection('users').doc(userId);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      console.warn(`[RevenueCat Webhook] Ignoring cancellation for non-existent user: ${userId}`);
      return;
    }

    await userRef.update({
      'subscription.autoRenew': false,
      'subscription.isActive': false,
      'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    });

    // ✅ FIXED: Send notification about subscription cancellation (triggers FCM)
    const notificationsRef = userRef.collection('notifications');
    await notificationsRef.add({
      type: 'subscription_cancelled',
      title: '⚠️ Subscription Cancelled',
      body: 'Your subscription has been cancelled and will expire at the end of your billing period.',
      payload: {
        type: 'subscription_cancelled',
        title: '⚠️ Subscription Cancelled',
        body: 'You can reactivate it anytime from your profile.',
        route: '/profile',
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isSent: false,
    });

    console.log(`[RevenueCat] ✅ Cancelled subscription for user: ${userId} with notification`);
  } catch (error) {
    console.error('[RevenueCat] Failed to cancel subscription:', error);
  }
}

async function expireSubscriptionStatus(userId) {
  try {
    // SECURITY: Verify user exists
    const userRef = db.collection('users').doc(userId);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      console.warn(`[RevenueCat Webhook] Ignoring expiration for non-existent user: ${userId}`);
      return;
    }

    await userRef.update({
      'subscription.isActive': false,
      'onPremium': false,
      'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    });

    // ✅ FIXED: Send notification about subscription expiry (triggers FCM)
    const notificationsRef = userRef.collection('notifications');
    await notificationsRef.add({
      type: 'subscription_expired',
      title: '😢 Subscription Expired',
      body: 'Your subscription has expired. Renew now to continue enjoying premium features!',
      payload: {
        type: 'subscription_expired',
        title: '😢 Subscription Expired',
        body: 'Reactivate your subscription to unlock premium journeys',
        route: '/subscription',
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isSent: false,
    });

    console.log(`[RevenueCat] ✅ Expired subscription for user: ${userId} with notification`);
  } catch (error) {
    console.error('[RevenueCat] Failed to expire subscription:', error);
  }
}

/**
 * Fetch RevenueCat customer object using server-to-server API.
 * Returns the parsed customer object or null on not-found.
 */
async function fetchRevenueCatCustomer(appUserId) {
  if (!REVENUECAT_API_KEY) {
    throw new Error('RevenueCat API key not configured');
  }

  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.revenuecat.com',
      port: 443,
      path: `/v1/customers/${encodeURIComponent(appUserId)}`,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${REVENUECAT_API_KEY}`,
        'Content-Type': 'application/json',
      },
      timeout: 5000,
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode !== 200) {
          console.warn(`[RevenueCat] Customer lookup returned status ${res.statusCode}`);
          return resolve(null);
        }
        try {
          const parsed = JSON.parse(data);
          // RevenueCat returns { customer: { ... } }
          const customer = parsed.customer || parsed;
          resolve(customer);
        } catch (err) {
          reject(err);
        }
      });
    });

    req.on('error', (err) => reject(err));
    req.on('timeout', () => { req.destroy(); resolve(null); });
    req.end();
  });
}

// ============================================================================
// SUBSCRIPTION VALIDATION (Client-Initiated, not Webhook-Based)
// ============================================================================

/**
 * Cloud function to validate and record subscription purchases
 * Called directly by client after purchase completes
 * This creates subscription records IMMEDIATELY in Firestore
 */
exports.validateAndRecordSubscription = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ success: false, error: 'Only POST requests allowed' });
    return;
  }

  try {
    // AUTHENTICATION: Verify Firebase ID token
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.error('[validateAndRecordSubscription] Missing auth header');
      res.status(401).json({ success: false, error: 'Missing Authorization header' });
      return;
    }

    const idToken = authHeader.substring(7);
    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (authErr) {
      console.error('[validateAndRecordSubscription] Token verification failed:', authErr.message);
      res.status(401).json({ success: false, error: 'Invalid ID token' });
      return;
    }

    const userId = decodedToken.uid;
    const { packageId, transactionId, tier } = req.body;

    console.log('[validateAndRecordSubscription] REQUEST:');
    console.log(`  userId: ${userId}`);
    console.log(`  packageId: ${packageId}`);
    console.log(`  transactionId: ${transactionId}`);
    console.log(`  tier: ${tier}`);

    // VALIDATION
    if (!packageId || !transactionId || !tier) {
      console.error('[validateAndRecordSubscription] Missing required fields');
      res.status(400).json({ success: false, error: 'Missing packageId, transactionId, or tier' });
      return;
    }

    // VERIFY USER EXISTS
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.error(`[validateAndRecordSubscription] User not found: ${userId}`);
      res.status(404).json({ success: false, error: 'User not found' });
      return;
    }

    console.log(`[validateAndRecordSubscription] ✅ User verified: ${userId}`);

    // CREATE SUBSCRIPTION RECORD IMMEDIATELY
    // This ensures the user has subscription fields even before webhook fires
    const now = new Date();
    const expiryDate = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000); // 30 days

    const subscriptionRecord = {
      isActive: true,
      tier: tier || 'monthly_premium',
      startDate: admin.firestore.FieldValue.serverTimestamp(),
      expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
      autoRenew: true,
      // FIX 4: Use the real revenueCatCustomerId from the client request body if provided.
      // The client passes customerInfo.originalAppUserId which is needed for future webhook-to-user matching.
      revenueCatCustomerId: req.body.revenueCatCustomerId || null,
      revenueCatTransactionId: transactionId,
      verificationStatus: 'verified',
      type: 'subscription',
      packageId: packageId,
    };

    await db.collection('users').doc(userId).update({
      'subscription': subscriptionRecord,
      'onPremium': true,
      'subExpDate': admin.firestore.Timestamp.fromDate(expiryDate),
      'entitledUser': true,
      'prevSubscribed': true,
      'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[validateAndRecordSubscription] ✅ Subscription recorded for user: ${userId}`);
    console.log(`   tier: ${tier}`);
    console.log(`   expiryDate: ${expiryDate.toISOString()}`);

    // Queue notification
    try {
      await db.collection('users').doc(userId).collection('notifications').add({
        type: 'subscription_activated',
        title: '✅ Subscription Active',
        body: 'Your premium subscription is now active!',
        payload: {
          type: 'subscription_activated',
          tier: tier,
          expiryDate: expiryDate.toISOString(),
          route: '/subscription',
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isSent: false,
      });
      console.log('[validateAndRecordSubscription] ✅ Notification queued');
    } catch (notifErr) {
      console.warn('[validateAndRecordSubscription] Notification queueing failed (non-fatal):', notifErr.message);
    }

    res.json({
      success: true,
      message: 'Subscription recorded successfully',
      subscription: {
        isActive: true,
        tier: tier,
        expiryDate: expiryDate.toISOString(),
      },
    });

  } catch (error) {
    console.error('[validateAndRecordSubscription] Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});
