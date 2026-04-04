const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function activateIOSSubscription() {
  const userId = 'YwCMlX39kcZH3F4WHb53twQsM1q1';
  const expiryDate = new Date('2026-04-28T00:00:00Z');
  const expiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);
  
  console.log(`\n=== ACTIVATING iOS USER SUBSCRIPTION ===\n`);

  try {
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.error(`❌ User not found`);
      process.exit(1);
    }

    const userData = userDoc.data();
    const email = userData.email || 'unknown';
    console.log(`User: ${email}\n`);

    const subscriptionRecord = {
      isActive: true,
      tier: 'monthly_premium',
      startDate: admin.firestore.Timestamp.now(),
      expiryDate: expiryTimestamp,
      autoRenew: true,
      revenueCatCustomerId: null,
      revenueCatSubscriptionId: null,
    };

    await userDoc.ref.collection('subscription').doc('current').set(subscriptionRecord);

    const userUpdate = {
      'subscription': subscriptionRecord,
      'onPremium': true,
      'subExpDate': expiryTimestamp,
      'entitledUser': true,
      'updatedAt': admin.firestore.Timestamp.now(),
    };

    await userDoc.ref.update(userUpdate);

    await userDoc.ref.collection('audit_log').add({
      action: 'subscription_activated',
      tier: 'monthly_premium',
      expiryDate: expiryDate,
      reason: 'manual_activation_ios_no_sync',
      activatedBy: 'admin_script',
      timestamp: admin.firestore.Timestamp.now(),
      details: {
        issue: 'iOS user subscribed but subscription did not sync',
        possibleCause: 'Old build or webhook failure',
        solution: 'Manually activated with both V1 and V2 schema'
      }
    });

    const updatedUserDoc = await userDoc.ref.get();
    const updatedData = updatedUserDoc.data();
    
    console.log('✅ Subscription Activated:');
    console.log(`  - Tier: ${updatedData.subscription.tier}`);
    console.log(`  - Expires: April 28, 2026`);
    console.log(`  - Active: Yes`);
    console.log(`  - Schema: V1 (onPremium) + V2 (subscription object)\n`);

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

activateIOSSubscription();
