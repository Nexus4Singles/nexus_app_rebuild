const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccount.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://nexus-project-c49a0.firebaseio.com"
  });
}

const db = admin.firestore();

async function awardSubscription(userId, expiryDateStr) {
  try {
    console.log(`🔄 Awarding subscription for user ${userId}...`);

    // Parse expiry date
    const expiryDate = new Date(expiryDateStr);
    expiryDate.setHours(0, 0, 0, 0);
    const expiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);
    const transactionId = `manual_award_${Date.now()}`;

    // Update user document with subscription
    const userRef = db.collection('users').doc(userId);
    await userRef.update({
      'onPremium': true,
      'entitledUser': true,
      'prevSubscribed': true,
      'subscription.isActive': true,
      'subscription.type': 'subscription',
      'subscription.tier': 'monthly',
      'subscription.packageId': 'manual_award',
      'subscription.revenueCatTransactionId': transactionId,
      'subscription.expiryDate': expiryTimestamp,
      'subscription.startDate': admin.firestore.FieldValue.serverTimestamp(),
      'subscription.autoRenew': true,
      'subscription.optimisticRecord': false,
      'subscription.verificationStatus': 'verified',
      'subExpDate': expiryTimestamp,
      'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Subscription awarded for user ${userId} until ${expiryDateStr} (tx=${transactionId})`);

    // Queue notification so the Cloud Function can send an activation push
    try {
      await userRef.collection('notifications').add({
        type: 'subscription_activated',
        title: '✅ Subscription Active',
        body: 'Your premium subscription is now active!',
        payload: {
          type: 'subscription_activated',
          tier: 'monthly',
          expiryDate: expiryTimestamp.toDate().toISOString(),
          route: '/subscription',
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isSent: false,
      });
      console.log(`✅ Subscription activation notification queued for ${userId}`);
    } catch (notifErr) {
      console.warn(`⚠️ Notification queueing failed for ${userId}:`, notifErr.message);
    }

    // Get updated user document for display
    const userDoc = await userRef.get();
    const userData = userDoc.data();
    
    console.log('--- User document snapshot after update ---');
    console.log(JSON.stringify(userData, null, 2));
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

const userId = process.argv[2];
const expiryDate = process.argv[3];

if (!userId || !expiryDate) {
  console.log('Usage: node scripts/award_subscription.js <userId> <expiryDate>');
  console.log('Example: node scripts/award_subscription.js abc123 2026-05-30');
  process.exit(1);
}

awardSubscription(userId, expiryDate).then(() => process.exit(0));
