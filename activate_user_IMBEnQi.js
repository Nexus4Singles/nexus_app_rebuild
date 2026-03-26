const admin = require('firebase-admin');
const https = require('https');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();
const apiKey = process.env.REVENUECAT_API_KEY;

async function queryRevenueCAT(userId) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.revenuecat.com',
      port: 443,
      path: `/v1/subscribers/${userId}`,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      timeout: 10000,
    };

    const req = https.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        try {
          if (res.statusCode === 404) {
            resolve({ found: false, statusCode: 404 });
            return;
          }
          if (res.statusCode !== 200) {
            resolve({ statusCode: res.statusCode, error: data });
            return;
          }
          const parsedData = JSON.parse(data);
          resolve({ found: true, data: parsedData });
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
    req.end();
  });
}

async function activateSubscription() {
  const userId = 'IMBEnQigtsbRYghhvdVfbSKmqKh1';
  
  console.log(`\n=== ACTIVATING SUBSCRIPTION FOR ${userId} ===\n`);

  try {
    // 1. Get user data from Firestore
    console.log('📋 Fetching user data from Firestore...');
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.error(`❌ User ${userId} not found in Firestore`);
      process.exit(1);
    }

    const userData = userDoc.data();
    const email = userData.email || 'unknown';
    console.log(`✓ User found: ${email}`);

    // 2. Query RevenueCat to get subscription details
    console.log('\n🔍 Querying RevenueCat API...');
    const rcResult = await queryRevenueCAT(userId);

    let expiryDate = null;
    let rcNotes = 'RevenueCat data unavailable';

    if (rcResult.found && rcResult.data) {
      const subscriber = rcResult.data.subscriber;
      const entitlements = subscriber.entitlements || {};
      
      // Find active entitlement
      for (const [key, value] of Object.entries(entitlements)) {
        if (value.expires_date) {
          expiryDate = new Date(value.expires_date);
          rcNotes = `Retrieved from RevenueCat entitlement: ${key}`;
          console.log(`✓ Found active subscription with expiry: ${expiryDate.toISOString()}`);
          break;
        }
      }

      // If no active entitlement, use current + 30 days
      if (!expiryDate) {
        expiryDate = new Date();
        expiryDate.setDate(expiryDate.getDate() + 30);
        rcNotes = 'No active entitlement in RevenueCat, using default +30 days';
        console.log(`⚠️  No active entitlement found, using default expiry: ${expiryDate.toISOString()}`);
      }

      console.log(`App User ID in RevenueCat: ${subscriber.app_user_id || 'NOT SET (anonymous)'}`);
    } else {
      // Fallback: use +30 days from today
      expiryDate = new Date();
      expiryDate.setDate(expiryDate.getDate() + 30);
      rcNotes = 'RevenueCat query failed, using default +30 days';
      console.log(`⚠️  RevenueCat query failed, using default expiry: ${expiryDate.toISOString()}`);
    }

    // 3. Create subscription record
    console.log('\n📝 Creating subscription...');
    const subscriptionRecord = {
      tier: 'monthly_premium',
      isActive: true,
      expiryDate: expiryDate,
      autoRenew: true,
      startDate: admin.firestore.Timestamp.now(),
      revenueCatCustomerId: null,
      revenueCatTransactionId: 'sub_nexus_premium_v2_manual',
      validatedBy: 'manual_activation',
      verificationStatus: 'verified',
      validatedAt: admin.firestore.Timestamp.now(),
      type: 'subscription',
      packageId: 'monthly_premium_v2',
    };

    await db.collection('users').doc(userId).collection('subscription').doc('current').set(subscriptionRecord);
    console.log('✓ Created subscription/current document');

    // 4. Update user doc with subscription fields
    const userUpdate = {
      'subscription': subscriptionRecord,
      'onPremium': true,
      'subExpDate': expiryDate,
      'entitledUser': true,
      'updatedAt': admin.firestore.Timestamp.now(),
    };

    await db.collection('users').doc(userId).update(userUpdate);
    console.log('✓ Updated user doc with subscription fields');

    // 5. Create audit log
    await db.collection('users').doc(userId).collection('audit_log').add({
      action: 'subscription_activated',
      tier: 'monthly_premium',
      expiryDate: expiryDate,
      reason: 'manual_activation_android_webhook_failure',
      activatedBy: 'admin_script',
      timestamp: admin.firestore.Timestamp.now(),
      details: {
        issue: 'RevenueCat webhook failed due to app_user_id not set',
        revenueCatTransaction: 'sub_nexus_premium_v2_manual',
        rcNotes: rcNotes,
        notes: 'Android race condition: Purchases.logIn() not called before purchase'
      }
    });
    console.log('✓ Created audit log entry');

    // 6. Verify
    console.log('\n✅ VERIFICATION');
    const subDoc = await db.collection('users').doc(userId).collection('subscription').doc('current').get();
    const updatedUser = await db.collection('users').doc(userId).get();

    console.log(`Subscription record: ${subDoc.exists ? '✓' : '✗'}`);
    if (subDoc.exists) {
      const sub = subDoc.data();
      console.log(`  - Tier: ${sub.tier}`);
      console.log(`  - Active: ${sub.isActive}`);
      console.log(`  - Expires: ${sub.expiryDate.toDate()}`);
      console.log(`  - Verified: ${sub.verificationStatus}`);
    }

    const ud = updatedUser.data();
    console.log(`User premium fields: ${ud.subscription ? '✓' : '✗'}`);
    if (ud.subscription) {
      console.log(`  - onPremium: ${ud.onPremium}`);
      console.log(`  - entitledUser: ${ud.entitledUser}`);
    }

    console.log(`\n✅ SUBSCRIPTION ACTIVATED SUCCESSFULLY`);
    console.log(`User ${userId} (${email}) can now use premium features`);
    console.log(`Expires: ${expiryDate.toISOString()}\n`);

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

activateSubscription();
