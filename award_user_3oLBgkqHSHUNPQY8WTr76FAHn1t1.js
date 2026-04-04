const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function awardUserSubscription() {
  try {
    const userId = '3oLBgkqHSHUNPQY8WTr76FAHn1t1';
    
    console.log('\n=== CHECKING & AWARDING SUBSCRIPTION ===\n');
    console.log(`User ID: ${userId}\n`);

    // Get user document
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.log('❌ User not found in Firestore');
      process.exit(1);
    }

    const userData = userDoc.data();
    console.log(`✅ User found: ${userData.email || userData.username || 'Unknown'}\n`);

    // Check current subscription
    const currentSub = userData.subscription;
    const isCurrentlyActive = currentSub?.isActive && currentSub?.expiryDate?.toDate?.() > new Date();
    
    console.log('Current subscription status:');
    console.log(`  Active: ${isCurrentlyActive ? '✅ YES' : '❌ NO'}`);
    if (currentSub?.expiryDate) {
      console.log(`  Expires: ${currentSub.expiryDate?.toDate?.()?.toISOString()}`);
    }

    if (isCurrentlyActive) {
      console.log('\n⚠️  User already has active subscription - skipping\n');
      process.exit(0);
    }

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

    console.log('\n✅ SUBSCRIPTION AWARDED!\n');
    console.log('Details:');
    console.log(`  Tier: monthly_premium`);
    console.log(`  Expires: ${expiryDate.toISOString()}`);
    console.log(`  Status: isActive=true\n`);

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
      console.log('📢 Notification queued\n');
    } catch (notifError) {
      console.log('⚠️  Notification failed (non-fatal)\n');
    }

    console.log('✅ User can now access premium features!');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

awardUserSubscription();
