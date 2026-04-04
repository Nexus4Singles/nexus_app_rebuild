const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function awardSubscriptionMay3() {
  try {
    const email = 'doguntade@yahoo.com';
    const expiryDateStr = '2026-05-03';

    console.log('\n=== AWARDING SUBSCRIPTION ===\n');
    console.log(`Email: ${email}`);
    console.log(`Expiry: ${expiryDateStr}\n`);

    // Find user by email
    console.log('Finding user...');
    const userQuery = await db.collection('users').where('email', '==', email).limit(1).get();

    if (userQuery.empty) {
      console.log('❌ User not found');
      process.exit(1);
    }

    const userDoc = userQuery.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();

    console.log(`✅ Found user: ${userId}\n`);

    // Check current subscription
    const currentSub = userData.subscription;
    const isCurrentlyActive = currentSub?.isActive && currentSub?.expiryDate?.toDate?.() > new Date();
    
    if (isCurrentlyActive) {
      console.log('Current subscription:');
      console.log(`  Status: ✅ Active`);
      console.log(`  Expiry: ${currentSub.expiryDate?.toDate?.()?.toISOString()}`);
      console.log('  Updating to May 3...\n');
    }

    // Parse expiry date (2026-05-03)
    const expiryDate = new Date(expiryDateStr + 'T23:59:59Z');
    const expiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);

    console.log(`Setting expiry to: ${expiryDate.toISOString()}\n`);

    // Create V2 subscription record
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

    // Update user document with BOTH V1 and V2 fields
    await db.collection('users').doc(userId).update({
      // V2 format (new)
      'subscription': subscriptionRecord,
      // V1 format (legacy)
      'onPremium': true,
      'subExpDate': expiryTimestamp,
      'entitledUser': true,
      'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('✅ SUBSCRIPTION AWARDED!\n');
    console.log('Updated fields:');
    console.log(`  onPremium: true`);
    console.log(`  subExpDate: ${expiryDate.toISOString()}`);
    console.log(`  subscription.isActive: true`);
    console.log(`  subscription.tier: monthly_premium`);
    console.log(`  subscription.expiryDate: ${expiryDate.toISOString()}`);
    console.log(`  subscription.verificationStatus: verified\n`);

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

    console.log('✅ Subscription awarded with May 3 expiry!');

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

awardSubscriptionMay3();
