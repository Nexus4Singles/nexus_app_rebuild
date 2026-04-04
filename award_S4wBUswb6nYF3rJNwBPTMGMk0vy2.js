const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function awardSubscriptionByUserId() {
  try {
    const userId = 'S4wBUswb6nYF3rJNwBPTMGMk0vy2';
    const expiryDateStr = '2026-04-30';

    console.log('\n=== AWARDING SUBSCRIPTION ===\n');
    console.log(`User ID: ${userId}`);
    console.log(`Expiry: ${expiryDateStr}\n`);

    // Get user by ID
    console.log('Finding user...');
    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      console.log('❌ User not found');
      process.exit(1);
    }

    const userData = userDoc.data();
    console.log(`✅ Found user: ${userData.email || userData.username || 'Unknown'}\n`);

    // Check current subscription
    const currentSub = userData.subscription;
    const isCurrentlyActive = currentSub?.isActive && currentSub?.expiryDate?.toDate?.() > new Date();
    
    if (isCurrentlyActive) {
      console.log('Current subscription:');
      console.log(`  Status: ✅ Active`);
      console.log(`  Expiry: ${currentSub.expiryDate?.toDate?.()?.toISOString()}`);
      console.log('  Updating to new date...\n');
    }

    // Parse expiry date (2026-04-30)
    const expiryDate = new Date(expiryDateStr + 'T23:59:59Z');
    const expiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);

    console.log(`Setting expiry to: ${expiryDate.toISOString()}\n`);

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

    console.log('✅ SUBSCRIPTION AWARDED!\n');
    console.log('Details:');
    console.log(`  User ID: ${userId}`);
    console.log(`  Email: ${userData.email || 'NOT SET'}`);
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

    console.log('✅ User can now access all premium features!');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

awardSubscriptionByUserId();
