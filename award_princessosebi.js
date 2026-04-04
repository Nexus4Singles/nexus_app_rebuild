const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function awardSubscription() {
  const email = 'princessosebi@yahoo.com';
  const expiryDate = new Date('2026-04-27T00:00:00Z');
  const expiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);
  
  console.log(`\n=== AWARDING SUBSCRIPTION ===\n`);
  console.log(`Email: ${email}`);
  console.log(`Expiry: April 27, 2026\n`);

  try {
    const usersSnapshot = await db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.error(`❌ User not found`);
      process.exit(1);
    }

    const userDoc = usersSnapshot.docs[0];
    const userData = userDoc.data();
    
    console.log(`✓ User found: ${userData.username || userData.name}\n`);

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
      action: 'subscription_awarded',
      tier: 'monthly_premium',
      expiryDate: expiryDate,
      reason: 'manual_subscription_award',
      activatedBy: 'admin_script',
      timestamp: admin.firestore.Timestamp.now(),
      details: {
        expiryDate: expiryDate.toISOString()
      }
    });

    console.log('✅ Subscription Awarded:');
    console.log(`  - Tier: monthly_premium`);
    console.log(`  - Expires: April 27, 2026`);
    console.log(`  - Active: Yes\n`);

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

awardSubscription();
