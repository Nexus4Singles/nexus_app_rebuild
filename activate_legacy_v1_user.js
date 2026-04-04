const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function activateLegacyUserSubscription() {
  try {
    const userId = '4VfkP1F73UScQhnp1j8YnlvC2Wc2';

    console.log('\n=== ACTIVATING LEGACY V1 USER SUBSCRIPTION ===\n');
    console.log(`User ID: ${userId}\n`);

    // Get user document
    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      console.log('❌ User not found');
      process.exit(1);
    }

    const userData = userDoc.data();
    console.log(`✅ Found user: ${userData.email || userData.username || 'Unknown'}\n`);

    // Show current schema
    console.log('Current document structure:');
    console.log('  onPremium:', userData.onPremium || 'NOT SET');
    console.log('  subExpDate:', userData.subExpDate?.toDate?.()?.toISOString() || 'NOT SET');
    console.log('  subscription:', userData.subscription ? 'EXISTS' : 'NOT SET');
    console.log();

    // Set 30-day expiry from today
    const expiryDate = new Date();
    expiryDate.setDate(expiryDate.getDate() + 30);
    const expiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);

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

    console.log('✅ SUBSCRIPTION ACTIVATED!\n');
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

    console.log('✅ Legacy V1 user now has subscription activated!');
    console.log('Both V1 (onPremium) and V2 (subscription) fields are set.');

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

activateLegacyUserSubscription();
