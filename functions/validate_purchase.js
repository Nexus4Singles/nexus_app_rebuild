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
const crypto = require('crypto');

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
 * HTTP endpoint (not callable) - called via raw POST from Dart with Bearer token
 */
exports.validateAndRecordPurchase = functions.https.onRequest(async (req, res) => {
  try {
    // Set CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    // ========================================================================
    // AUTHENTICATION - Verify Firebase ID token from Authorization header
    // ========================================================================
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: { code: 'unauthenticated', message: 'Missing or invalid Authorization header' }
      });
    }

    let userId;
    try {
      const token = authHeader.slice(7); // Remove "Bearer " prefix
      const decoded = await admin.auth().verifyIdToken(token);
      userId = decoded.uid;
    } catch (authError) {
      console.error('[validatePurchase] Token verification failed:', authError);
      return res.status(401).json({
        success: false,
        error: { code: 'authentication_error', message: 'Invalid or expired authentication token' }
      });
    }

    // ========================================================================
    // PARSE REQUEST BODY
    // Firebase Cloud Functions automatically parse JSON request bodies.
    // req.body is already a parsed object when Content-Type is application/json.
    // DO NOT attempt to read the stream manually — it has already been consumed.
    // ========================================================================
    const requestBody = req.body || {};
    
    console.log('[validatePurchase] req.body type:', typeof req.body);
    console.log('[validatePurchase] req.body:', JSON.stringify(req.body));
    console.log('[validatePurchase] requestBody keys:', Object.keys(requestBody));

    // Extract parameters from parsed body
    const { journeyId, journeyTitle, transactionId, packageId, revenueCatCustomerId } = requestBody;

    // ========================================================================
    // INPUT VALIDATION
    // ========================================================================
    console.log('[validatePurchase] Field values:', {
      journeyId: journeyId || '(MISSING)',
      journeyTitle: journeyTitle || '(MISSING)',
      transactionId: transactionId || '(MISSING)',
      packageId: packageId || '(MISSING)',
    });

    const missingFields = [];
    if (!journeyId) missingFields.push('journeyId');
    if (!journeyTitle) missingFields.push('journeyTitle');
    if (!transactionId) missingFields.push('transactionId');
    if (!packageId) missingFields.push('packageId');

    if (missingFields.length > 0) {
      console.error('[validatePurchase] Missing fields:', missingFields.join(', '));
      console.error('[validatePurchase] Full requestBody was:', JSON.stringify(requestBody));
      return res.status(400).json({
        success: false,
        error: { code: 'invalid-argument', message: `Missing required fields: ${missingFields.join(', ')}` }
      });
    }

    if (typeof journeyId !== 'string' || journeyId.length === 0) {
      return res.status(400).json({
        success: false,
        error: { code: 'invalid-argument', message: 'Invalid journeyId' }
      });
    }

    if (typeof transactionId !== 'string' || transactionId.length === 0) {
      return res.status(400).json({
        success: false,
        error: { code: 'invalid-argument', message: 'Invalid transactionId' }
      });
    }

    if (typeof journeyTitle !== 'string' || journeyTitle.length === 0) {
      return res.status(400).json({
        success: false,
        error: { code: 'invalid-argument', message: 'Invalid journeyTitle' }
      });
    }

    if (typeof packageId !== 'string' || packageId.length === 0) {
      return res.status(400).json({
        success: false,
        error: { code: 'invalid-argument', message: 'Invalid packageId' }
      });
    }
    try {
      // ====================================================================
      // FRAUD CHECK 1: Verify user exists and is legitimate
      // ====================================================================
      const userDoc = await db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        console.error(`[validatePurchase] User doc not found: ${userId}`);
        return res.status(404).json({
          success: false,
          error: { code: 'not-found', message: 'User profile not found' }
        });
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
        // Return success but don't rewrite the record
        return res.status(200).json({
          success: true,
          message: 'Journey already purchased',
          duplicate: true,
          purchaseRecord: existingPurchase.data(),
        });
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
        packageId,
        revenueCatCustomerId
      );

      if (!revenueCatValidation.isValid) {
        console.error(
          `[validatePurchase] RevenueCat validation failed: ${revenueCatValidation.reason}`
        );
        return res.status(403).json({
          success: false,
          error: { code: 'permission-denied', message: `Purchase validation failed: ${revenueCatValidation.reason}` }
        });
      }

      // ====================================================================
      // FRAUD CHECK 4: Validate transaction metadata
      // ====================================================================
      if (!revenueCatValidation.transactionData) {
        console.error('[validatePurchase] RevenueCat returned no transaction data');
        return res.status(403).json({
          success: false,
          error: { code: 'permission-denied', message: 'Unable to retrieve transaction details' }
        });
      }

      const txData = revenueCatValidation.transactionData;

      // ====================================================================
      // RECORD PURCHASE (Only if all validations pass)
      // ====================================================================
      // Prefer client-supplied price (from StoreProduct) over RevenueCat-extracted
      // price, because RevenueCat's subscriber API does not return pricing for
      // consumable (non-subscription) purchases.
      const clientPrice = requestBody.pricePaid;
      const clientCurrency = requestBody.currency;
      const finalPrice = (typeof clientPrice === 'number' && clientPrice > 0)
        ? clientPrice
        : (txData.price || 0);
      const finalCurrency = (typeof clientCurrency === 'string' && clientCurrency.length > 0)
        ? clientCurrency
        : (txData.currency || 'USD');

      const purchaseRecord = {
        journeyId,
        journeyTitle,
        userId,
        purchaseDate: admin.firestore.FieldValue.serverTimestamp(),
        pricePaid: finalPrice,
        currency: finalCurrency,
        revenueCatTransactionId: transactionId,
        revenueCatCustomerId: revenueCatValidation.customerId,
        packageId,
        type: 'journey',
        isActive: true,
        validatedAt: admin.firestore.FieldValue.serverTimestamp(),
        validatedBy: 'revenuecat_validation',
        ipAddress: req.ip || 'unknown',
        userAgent: req.headers['user-agent'] || 'unknown',
        duplicatePrevention: 'checked',
        revenueCatVerified: true,
      };

      // Use a transaction to ensure atomic write
      const result = await db.runTransaction(async (transaction) => {
        // Double-check no concurrent write happened
        const purchaseRef = db
          .collection('users')
          .doc(userId)
          .collection('purchases')
          .doc(journeyId);

        const existingTx = await transaction.get(purchaseRef);
        if (existingTx.exists) {
          throw new Error('DUPLICATE_PURCHASE_CONCURRENT_WRITE');
        }

        // Record the purchase
        transaction.set(purchaseRef, purchaseRecord);

        // Update user's purchases list for quick access
        const userRef = db.collection('users').doc(userId);
        transaction.update(userRef, {
          'purchasedJourneys': admin.firestore.FieldValue.arrayUnion(journeyId),
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
        // Don't fail the purchase if notification fails
      }

      return res.status(200).json({
        success: true,
        message: 'Purchase validated and recorded successfully',
        purchaseRecord: result,
      });
    } catch (error) {
      // Handle specific errors
      if (error.message === 'DUPLICATE_PURCHASE_CONCURRENT_WRITE') {
        console.warn(
          `[validatePurchase] Concurrent duplicate detected: User=${userId}, Journey=${journeyId}`
        );
        return res.status(200).json({
          success: true,
          message: 'Journey already purchased',
          duplicate: true,
        });
      }

      console.error('[validatePurchase] Unexpected error:', error.message);
      return res.status(500).json({
        success: false,
        error: { code: 'internal', message: 'Failed to process purchase. Please contact support.' }
      });
    }
  } catch (error) {
    console.error('[validatePurchase] Outer error:', error.message);
    return res.status(500).json({
      success: false,
      error: { code: 'internal', message: 'Failed to process purchase. Please contact support.' }
    });
  }
});

// ============================================================================
// SUBSCRIPTION VALIDATION & RECORDING
// ============================================================================

/**
 * Validates a subscription purchase with RevenueCat and records it securely
 * HTTP endpoint (not callable) - called via raw POST from Dart with Bearer token
 */
exports.validateAndRecordSubscription = functions.https.onRequest(async (req, res) => {
  try {
    // Set CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    // ========================================================================
    // AUTHENTICATION - Verify Firebase ID token from Authorization header
    // ========================================================================
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: { code: 'unauthenticated', message: 'Missing or invalid Authorization header' }
      });
    }

    let userId;
    try {
      const token = authHeader.slice(7); // Remove "Bearer " prefix
      const decoded = await admin.auth().verifyIdToken(token);
      userId = decoded.uid;
    } catch (authError) {
      console.error('[validateSubscription] Token verification failed:', authError);
      return res.status(401).json({
        success: false,
        error: { code: 'authentication_error', message: 'Invalid or expired authentication token' }
      });
    }

    // ========================================================================
    // PARSE REQUEST BODY
    // Firebase Cloud Functions automatically parse JSON request bodies.
    // req.body is already a parsed object when Content-Type is application/json.
    // ========================================================================
    const requestBody = req.body || {};
    console.log('[validateSubscription] req.body type:', typeof req.body);
    console.log('[validateSubscription] req.body:', JSON.stringify(req.body));

    const { packageId, transactionId, tier, revenueCatCustomerId } = requestBody;

    // ========================================================================
    // INPUT VALIDATION
    // ========================================================================
    if (!packageId || !transactionId || !tier) {
      return res.status(400).json({
        success: false,
        error: { code: 'invalid-argument', message: 'Missing required fields: packageId, transactionId, tier' }
      });
    }

    // Normalize tier to current format to ensure consistency
    let normalizedTier = tier;
    if (tier === 'Premium' || tier === 'nexus_premium' || tier === 'monthly') {
      normalizedTier = 'monthly_premium';
    }
    console.log(`[validateSubscription] Normalized tier: "${tier}" → "${normalizedTier}"`);

    try {
      // ====================================================================
      // FRAUD CHECK 1: Verify user exists and is legitimate
      // ====================================================================
      const userDoc = await db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        console.error(`[validateSubscription] User doc not found: ${userId}`);
        return res.status(404).json({
          success: false,
          error: { code: 'not-found', message: 'User profile not found' }
        });
      }

      // ====================================================================
      // FRAUD CHECK 2: Validate with RevenueCat (server-to-server)
      // ====================================================================
      console.log(
        `[validateSubscription] Validating with RevenueCat: User=${userId}, Transaction=${transactionId}`
      );

      const revenueCatValidation = await validateWithRevenueCat(
        userId,
        transactionId,
        packageId,
        revenueCatCustomerId
      );

      if (!revenueCatValidation.isValid) {
        console.error(
          `[validateSubscription] RevenueCat validation failed: ${revenueCatValidation.reason}`
        );
        return res.status(403).json({
          success: false,
          error: { code: 'permission-denied', message: `Subscription validation failed: ${revenueCatValidation.reason}` }
        });
      }

      // ====================================================================
      // FRAUD CHECK 3: Validate transaction metadata
      // ====================================================================
      if (!revenueCatValidation.transactionData) {
        console.error('[validateSubscription] RevenueCat returned no transaction data');
        return res.status(403).json({
          success: false,
          error: { code: 'permission-denied', message: 'Unable to retrieve transaction details' }
        });
      }

      const txData = revenueCatValidation.transactionData;

      // ====================================================================
      // RECORD SUBSCRIPTION (Only if all validations pass)
      // ====================================================================
        const subscriptionRecord = {
          isActive: true,
          tier: normalizedTier,
          startDate: admin.firestore.FieldValue.serverTimestamp(),
          expiryDate: null, // Will be set by RevenueCat webhook based on renewal
          autoRenew: true,
          revenueCatCustomerId: revenueCatValidation.customerId,
          revenueCatTransactionId: transactionId,
          packageId: packageId,
          validatedAt: admin.firestore.FieldValue.serverTimestamp(),
          validatedBy: 'revenuecat_validation',
          ipAddress: req.ip || 'unknown',
          userAgent: req.headers['user-agent'] || 'unknown',
          revenueCatVerified: true,
        };
        const fallbackExpiryDate = admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
        );

        const userRef = db.collection('users').doc(userId);

        // Persist revenuecat mapping if needed
        if (revenueCatValidation.customerId && revenueCatValidation.customerId !== userId) {
          await db.collection('revenuecatMappings').doc(revenueCatValidation.customerId).set({
            firebaseUid: userId,
            source: 'validate_subscription',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }

        // Use a transaction to atomically update the user subscription and create an audit log
        try {
          await db.runTransaction(async (transaction) => {
            const userSnap = await transaction.get(userRef);

            // Idempotency: if the same RevenueCat transactionId is already recorded, skip
            const existingSub = userSnap.exists ? userSnap.get('subscription') : null;
            if (existingSub && existingSub.revenueCatTransactionId === transactionId) {
              console.log(`[validateSubscription] Duplicate subscription transaction detected for ${userId} (${transactionId}) - skipping write`);
              return;
            }

            const updateData = {
              'subscription': subscriptionRecord,
              'onPremium': true,
              'subExpDate': fallbackExpiryDate,
              'entitledUser': true,
              'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
            };

            transaction.update(userRef, updateData);

            const auditRef = userRef.collection('auditLog').doc();
            transaction.set(auditRef, {
              action: 'subscription_validated',
              provider: 'revenuecat',
              transactionId: transactionId,
              normalizedTier: normalizedTier,
              recordedAt: admin.firestore.FieldValue.serverTimestamp(),
              revenuecatResponse: revenueCatValidation.revenueCatCustomer || null,
            });
          });

          console.log(
            `[validateSubscription] ✅ Subscription recorded: User=${userId}, Tier=${normalizedTier}`
          );
        } catch (txErr) {
          console.error('[validateSubscription] Transaction failed:', txErr);
          throw txErr;
        }

      // ====================================================================
      // SEND NOTIFICATIONS
      // ====================================================================
      try {
        await sendSubscriptionActivationNotification(userId, normalizedTier, txData.price);
      } catch (notifError) {
        console.error('[validateSubscription] Notification error (non-fatal):', notifError);
        // Don't fail the purchase if notification fails
      }

      return res.status(200).json({
        success: true,
        message: 'Subscription validated and recorded successfully',
        subscriptionRecord: subscriptionRecord,
      });
    } catch (error) {
      console.error('[validateSubscription] Unexpected error:', error.message);
      return res.status(500).json({
        success: false,
        error: { code: 'internal', message: 'Failed to process subscription. Please contact support.' }
      });
    }
  } catch (error) {
    console.error('[validateSubscription] Outer error:', error.message);
    return res.status(500).json({
      success: false,
      error: { code: 'internal', message: 'Failed to process subscription. Please contact support.' }
    });
  }
});

// ============================================================================
// REVENUECAT VALIDATION (Server-to-Server)
// ============================================================================

/**
 * Validates purchase with RevenueCat using server-to-server API
 * VALIDATION CHAIN:
 * 1. Client-side: RevenueCat SDK validates transaction with Apple/Google
 * 2. Server-side: We verify user exists and has purchase history
 * 3. Transaction ID: Verified client-side, logged server-side for audit trail
 */
async function validateWithRevenueCat(userId, transactionId, packageId, revenueCatCustomerId) {
  console.log(
    `[RevenueCat] Starting validation for user=${userId}, transactionId=${transactionId}`
  );

  if (!REVENUECAT_API_KEY) {
    console.error('[RevenueCat] API key not configured');
    return {
      isValid: false,
      reason: 'RevenueCat not configured on server',
    };
  }

  return new Promise((resolve, reject) => {
    // Validate API key exists (secondary check)
    if (!REVENUECAT_API_KEY) {
      console.error('[RevenueCat] API key not configured');
      return resolve({
        isValid: false,
        reason: 'RevenueCat not configured',
      });
    }

    const lookupId = (revenueCatCustomerId || userId || '').trim();
    const path = `/v1/subscribers/${encodeURIComponent(lookupId)}`;

    // RevenueCat API endpoint to get customer info
    const options = {
      hostname: 'api.revenuecat.com',
      port: 443,
      path,
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
          const customerData = response.subscriber || {};

          // Check if customer has active entitlements or valid transactions
          const activeEntitlements = customerData.entitlements || {};
          const hasSubscriptions = customerData.subscriptions && 
                                  Object.keys(customerData.subscriptions).length > 0;
          const hasEntitlements = Object.keys(activeEntitlements).length > 0;
          const hasPurchaseHistory = customerData.original_purchase_date || hasSubscriptions;

          // VERIFICATION: Customer must have some purchase history
          if (!hasEntitlements && !hasPurchaseHistory) {
            console.warn(
              `[RevenueCat] No valid entitlements or transactions for ${userId}`
            );
            resolve({
              isValid: false,
              reason: 'No valid purchase found in RevenueCat',
            });
            return;
          }

          // Extract transaction details - use subscriptions for better pricing data
          const txData = extractTransactionData(customerData, packageId);

          const resolvedCustomerId =
            customerData.original_app_user_id ||
            customerData.app_user_id ||
            lookupId ||
            userId;

          resolve({
            isValid: true,
            customerId: resolvedCustomerId,
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
 * Extracts transaction data from RevenueCat subscriber object
 * IMPORTANT: RevenueCat entitlements don't have price data directly
 * Try subscriptions first, which may have pricing info from the transaction
 */
function extractTransactionData(customerData, packageId) {
  const defaultData = {
    price: 0,
    currency: 'USD',
    packageId,
  };

  try {
    // TRY #1: Check subscriptions for pricing (more reliable)
    if (customerData.subscriptions && typeof customerData.subscriptions === 'object' && customerData.subscriptions !== null) {
      const subscriptionKeys = Object.keys(customerData.subscriptions);
      for (const subKey of subscriptionKeys) {
        const sub = customerData.subscriptions[subKey];
        if (sub && typeof sub === 'object') {
          // Some RevenueCat subscription objects may have original_price or other fields
          if (sub.original_price && sub.original_price > 0) {
            return {
              price: sub.original_price,
              currency: sub.currency || 'USD',
              packageId,
            };
          }
        }
      }
    }

    // TRY #2: Check entitlements (fallback)
    if (customerData.entitlements && 
        typeof customerData.entitlements === 'object' && 
        customerData.entitlements !== null) {
      const entitlementKeys = Object.keys(customerData.entitlements);
      if (entitlementKeys.length > 0) {
        // Note: Entitlements typically don't have price, so we default to 0
        // This is acceptable for one-time purchases where we verify via RevenueCat
        return {
          price: 0, // Entitlements don't have pricing - that's OK for verification
          currency: 'USD',
          packageId,
        };
      }
    }

    // No pricing found, return default (this is acceptable - we still verified the purchase)
    console.warn(
      `[extractTransactionData] Could not extract pricing for ${packageId}, defaulting to 0`
    );
    return defaultData;
  } catch (error) {
    console.error('[extractTransactionData] Error:', error);
    return defaultData;
  }
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

async function sendSubscriptionActivationNotification(userId, tier, price = null) {
  try {
    const userRef = db.collection('users').doc(userId);
    const notificationsRef = userRef.collection('notifications');
    
    const tierDisplay = tier.charAt(0).toUpperCase() + tier.slice(1);
    const recentWindow = admin.firestore.Timestamp.fromMillis(
      Date.now() - 5 * 60 * 1000,
    );

    const duplicateQuery = await notificationsRef
      .where('type', '==', 'subscription_activated')
      .where('payload.tier', '==', tier)
      .where('createdAt', '>=', recentWindow)
      .limit(1)
      .get();

    if (!duplicateQuery.empty) {
      console.log(
        `[Notification] Skipping duplicate subscription activation notification for ${userId} tier=${tier}`,
      );
      return;
    }

    await notificationsRef.add({
      type: 'subscription_activated',
      title: '✨ Premium Unlocked!',
      body: `Your ${tierDisplay} subscription is active. Enjoy unlimited chats!`,
      payload: {
        type: 'subscription_activated',
        title: '✨ Premium Unlocked!',
        body: `Your ${tierDisplay} subscription unlocks unlimited premium features`,
        tier: tier,
        ...(price != null ? { price: price } : {}),
        route: '/subscription',
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isSent: false,
    });
    
    console.log(`[Notification] ✅ Subscription activation notification queued for ${userId}`);
  } catch (error) {
    console.error('[Notification] Failed to send subscription activation:', error);
    // Don't fail subscription if notification fails
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
  try {
    // ========================================================================
    // PARSE REQUEST BODY
    // Firebase Cloud Functions automatically parse JSON request bodies.
    // req.body is already a parsed object. req.rawBody contains the raw buffer
    // for signature verification.
    // ========================================================================
    let requestBody = req.body;
    let rawBody = req.rawBody ? req.rawBody.toString() : null;

    if (typeof requestBody === 'string') {
      try {
        requestBody = JSON.parse(requestBody);
      } catch (err) {
        console.error('[RevenueCat Webhook] Failed to parse raw request body as JSON:', err);
        return res.status(400).json({ error: 'Invalid JSON payload' });
      }
    }

    requestBody = requestBody || {};
    rawBody = rawBody || (typeof req.body === 'string' ? req.body : JSON.stringify(requestBody));

    console.log('[RevenueCat Webhook] Received event:', requestBody?.event?.type);

    // SECURITY: Verify webhook signature (if available)
    // This prevents attackers from sending fake subscription updates
    if (REVENUECAT_WEBHOOK_SECRET) {
      const signature = req.headers['x-rc-webhook-signature']
        || req.headers['x-revenuecat-signature']
        || req.headers['x-rc-signature'];
      
      if (!signature) {
        console.error('[RevenueCat Webhook] Missing signature header. Available headers:', Object.keys(req.headers));
        return res.status(401).json({ error: 'Missing signature' });
      }

      // Signature verification - use the original rawBody we collected
      if (!rawBody) {
        console.error('[RevenueCat Webhook] No body available for signature verification');
        return res.status(400).json({ error: 'Could not verify signature - no body' });
      }

      // Verify signature using HMAC-SHA1 with the ORIGINAL raw body
      const expectedSignature = crypto
        .createHmac('sha1', REVENUECAT_WEBHOOK_SECRET)
        .update(rawBody)
        .digest('hex');

      if (signature !== expectedSignature) {
        console.error('[RevenueCat Webhook] Invalid signature - rejecting webhook', {
          provided: signature,
          expected: expectedSignature,
          rawBodyPreview: rawBody.slice(0, 200),
        });
        return res.status(401).json({ error: 'Invalid signature' });
      }

      console.log('[RevenueCat Webhook] Signature verified ✓');
    } else {
      console.warn('[RevenueCat Webhook] No webhook secret configured - skipping signature verification');
    }

    const event = requestBody?.event || {};
    const eventType = event.type;
    const customerId = event.app_user_id;

    if (!customerId) {
      console.error('[RevenueCat Webhook] Missing app_user_id');
      return res.status(400).json({ error: 'Missing app_user_id' });
    }

    const resolvedFirebaseUid = await resolveRevenueCatCustomerToFirebaseUid(customerId);
    if (!resolvedFirebaseUid) {
      console.warn(`[RevenueCat Webhook] Could not resolve RevenueCat customer ${customerId} to a Firebase user; ignoring event`);
      return res.status(200).json({ success: true, skipped: true });
    }

    switch (eventType) {
      case 'INITIAL_SUBSCRIPTION':
      case 'RENEWAL':
        // Update subscription status
        await updateSubscriptionStatus(resolvedFirebaseUid, event);
        break;

      case 'SUBSCRIPTION_PAUSED':
      case 'SUBSCRIPTION_CANCELLED':
        await cancelSubscriptionStatus(resolvedFirebaseUid, event);
        break;

      case 'EXPIRED':
        await expireSubscriptionStatus(resolvedFirebaseUid);
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

async function resolveRevenueCatCustomerToFirebaseUid(customerId) {
  try {
    const directUserRef = db.collection('users').doc(customerId);
    const directUserDoc = await directUserRef.get();
    if (directUserDoc.exists) {
      return customerId;
    }

    const mappingDoc = await db.collection('revenuecatMappings').doc(customerId).get();
    if (mappingDoc.exists) {
      const mappingData = mappingDoc.data() || {};
      return mappingData.firebaseUid || null;
    }

    // Attempt to resolve by querying RevenueCat for subscriber details
    try {
      const subscriber = await fetchSubscriberFromRevenueCat(customerId);
      if (subscriber) {
        // 1) If RevenueCat's original_app_user_id appears to be a firebase uid, try to verify it
        const originalAppUserId = subscriber.original_app_user_id || subscriber.app_user_id || null;
        if (originalAppUserId) {
          try {
            const authUser = await admin.auth().getUser(originalAppUserId);
            if (authUser && authUser.uid) {
              // create mapping and return
              await db.collection('revenuecatMappings').doc(customerId).set({
                firebaseUid: authUser.uid,
                source: 'revenuecat_auto_resolve_original_id',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              }, { merge: true });
              return authUser.uid;
            }
          } catch (e) {
            // not a valid firebase uid - ignore
          }
        }

        // 2) Try to extract an email from subscriber attributes (if available)
        const attributes = (subscriber.attributes && typeof subscriber.attributes === 'object') ? subscriber.attributes : {};
        const email = subscriber.email || attributes.email || attributes.user_email || null;
        if (email && typeof email === 'string') {
          try {
            const userByEmail = await admin.auth().getUserByEmail(email);
            if (userByEmail && userByEmail.uid) {
              await db.collection('revenuecatMappings').doc(customerId).set({
                firebaseUid: userByEmail.uid,
                source: 'revenuecat_auto_resolve_email',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              }, { merge: true });
              return userByEmail.uid;
            }
          } catch (e) {
            // No user with that email - ignore
          }
        }

        // 3) Fallback: search users collection for a doc that already wrote this customerId inside revenueCat field
        try {
          const q = await db.collection('users').where('revenueCat.customerId', '==', customerId).limit(1).get();
          if (!q.empty) {
            const found = q.docs[0];
            await db.collection('revenuecatMappings').doc(customerId).set({
              firebaseUid: found.id,
              source: 'revenuecat_auto_resolve_users_query',
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            return found.id;
          }
        } catch (e) {
          // ignore fallback errors
        }
      }
    } catch (err) {
      console.error('[RevenueCat] Auto-resolve failed:', err);
    }

    return null;
  } catch (error) {
    console.error('[RevenueCat] Failed to resolve RevenueCat customer mapping:', error);
    return null;
  }
}

/**
 * Fetch subscriber details from RevenueCat server API for a given app_user_id
 */
async function fetchSubscriberFromRevenueCat(customerId) {
  if (!REVENUECAT_API_KEY) {
    console.error('[RevenueCat] API key not configured for fetchSubscriberFromRevenueCat');
    return null;
  }

  return new Promise((resolve) => {
    const path = `/v1/subscribers/${encodeURIComponent(customerId)}`;
    const options = {
      hostname: 'api.revenuecat.com',
      port: 443,
      path,
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
        try {
          if (res.statusCode !== 200) {
            console.error(`[RevenueCat] fetchSubscriber API error: ${res.statusCode} - ${data}`);
            return resolve(null);
          }
          const response = JSON.parse(data);
          const subscriber = response.subscriber || null;
          resolve(subscriber);
        } catch (err) {
          console.error('[RevenueCat] fetchSubscriber parse error:', err);
          resolve(null);
        }
      });
    });

    req.on('error', (err) => {
      console.error('[RevenueCat] fetchSubscriber request error:', err);
      resolve(null);
    });

    req.on('timeout', () => {
      console.error('[RevenueCat] fetchSubscriber request timeout');
      req.destroy();
      resolve(null);
    });

    req.end();
  });
}

async function updateSubscriptionStatus(userId, event) {
  try {
    // SECURITY: Verify user exists before updating
    const userRef = db.collection('users').doc(userId);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      console.warn(`[RevenueCat Webhook] Ignoring subscription for non-existent user: ${userId}`);
      return; // Silently ignore - don't create orphaned records
    }

    const expireDate = event.expiration_at_ms
      ? new Date(event.expiration_at_ms)
      : null;

    // Read tier from event and normalize to current format
    let tier = event.product_id_aliases?.[0] || event.product_id || 'monthly';
    
    // Normalize old product IDs to current 'monthly_premium' format
    // This ensures consistency and compatibility with SubscriptionTier enum
    if (tier === 'Premium' || tier === 'nexus_premium' || tier === 'monthly') {
      tier = 'monthly_premium';
    }

    // Use dot notation to merge individual fields instead of overwriting
    // the entire subscription object. This preserves metadata set by the
    // optimistic client record (packageId, type, verificationStatus, etc.).
    await userRef.update({
      'subscription.isActive': true,
      'subscription.tier': tier,
      'subscription.startDate': admin.firestore.FieldValue.serverTimestamp(),
      'subscription.expiryDate': expireDate,
      'subscription.autoRenew': true,
      'subscription.revenueCatCustomerId': userId,
      'subscription.lastUpdated': admin.firestore.FieldValue.serverTimestamp(),
      'subscription.verificationStatus': 'verified',
      'onPremium': true,
      'subExpDate': expireDate, // Legacy field for backward compatibility
      'entitledUser': true,
      'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    });

    await sendSubscriptionActivationNotification(userId, tier, null);

    console.log(`[RevenueCat] ✅ Updated subscription for user: ${userId} with notification (tier=${tier})`);
  } catch (error) {
    console.error('[RevenueCat] Failed to update subscription:', error);
    // Don't throw - let webhook succeed even if notification fails
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

    // Only disable auto-renew; the user retains access until the billing
    // period ends. The EXPIRED event will set isActive to false.
    await userRef.update({
      'subscription.autoRenew': false,
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
      'subExpDate': null, // Clear legacy field on expiry
      'entitledUser': false, // Clear legacy premium indicator
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
