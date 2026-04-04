const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function awardSubscription() {
  try {
    const userId = 'nvfiqInGrZdXKuFmXGD03Qrsoas2';
    const email = 'esthercjude@gmail.com';
    
    console.log('\n=== AWARDING SUBSCRIPTION ===\n');
    console.log(`User: ${email}`);
    console.log(`ID: ${userId}\n`);

    // Calculate 30-day expiry from today
    const expiryDate = new Date();
    expiryDate.setDate(expiryDate.getDate() + 30);
    const expiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);

    // Create subscription record
    const subscriptionRecord = {
      isActive: true,
      tier: 'monthly_premium',
      startDate: admin.firestore.FieldValue.serverTimestamp(),
      expiryDate: expiryTimestamp,
      autoRenew: true,
      revenueCatCustomerId: null,
      verificationStatus: 'verified',
      type: 'subscription',
      packageId: 'monthly_premium_v2',
    };

    // Update user document with subscription
    await db.collection('users').doc(userId).update({
      'subscription': subscriptionRecord,
      'onPremium': true,
      'subExpDate': expiryTimestamp,
      'entitledUser': true,
      'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('✅ Subscription awarded successfully!\n');
    console.log('Details:');
    console.log(`  Tier: monthly_premium`);
    console.log(`  Expires: ${expiryDate.toISOString()}`);
    console.log(`  Status: isActive=true, onPremium=true\n`);

    // Create notification
    try {
      await db.collection('users').doc(userId).collection('notifications').add({
        type: 'subscription_activated',
        title: '✅ Subscription Active',
        body: `Your monthly premium subscription is now active until ${expiryDate.toLocaleDateString()}!`,
        payload: {
          type: 'subscription_activated',
          tier: 'monthly_premium',
          expiryDate: expiryDate.toISOString(),
          route: '/subscription',
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isSent: false,
      });
      console.log('📢 Notification queued for user\n');
    } catch (notifError) {
      console.log('⚠️  Notification failed (non-fatal):', notifError.message, '\n');
    }

    console.log('✅ Award complete! User can now:');
    console.log('  - Send unlimited messages');
    console.log('  - Access all premium features\n');

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

awardSubscription();
