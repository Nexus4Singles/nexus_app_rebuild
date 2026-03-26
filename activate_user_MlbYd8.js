const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function activateSubscription() {
  const userId = 'MlbYd8GEy9TtsfbRZ2zmhCv56yt1';
  
  // Set expiry to 1 month from today
  const expiryDate = new Date();
  expiryDate.setMonth(expiryDate.getMonth() + 1);
  
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

    // 2. Create subscription record
    console.log('\n📝 Creating subscription (1 month expiry)...');
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

    // 3. Update user doc with subscription fields
    const userUpdate = {
      'subscription': subscriptionRecord,
      'onPremium': true,
      'subExpDate': expiryDate,
      'entitledUser': true,
      'updatedAt': admin.firestore.Timestamp.now(),
    };

    await db.collection('users').doc(userId).update(userUpdate);
    console.log('✓ Updated user doc with subscription fields');

    // 4. Create audit log
    await db.collection('users').doc(userId).collection('audit_log').add({
      action: 'subscription_activated',
      tier: 'monthly_premium',
      expiryDate: expiryDate,
      reason: 'manual_subscription_award',
      activatedBy: 'admin_script',
      timestamp: admin.firestore.Timestamp.now(),
      details: {
        expiryToday: true,
        notes: 'Manual subscription award with today as expiry date'
      }
    });
    console.log('✓ Created audit log entry');

    // 5. Verify
    console.log('\n✅ VERIFICATION');
    const subDoc = await db.collection('users').doc(userId).collection('subscription').doc('current').get();
    const updatedUser = await db.collection('users').doc(userId).get();
    
    if (subDoc.exists) {
      const sub = subDoc.data();
      const user = updatedUser.data();
      console.log(`Email: ${user.email}`);
      console.log(`Tier: ${sub.tier}`);
      console.log(`Active: ${sub.isActive}`);
      console.log(`Expires: ${sub.expiryDate.toDate()}`);
      console.log(`Verified: ${sub.verificationStatus}`);
      console.log(`onPremium: ${user.onPremium}`);
      console.log(`entitledUser: ${user.entitledUser}`);
      console.log(`\n✅ SUBSCRIPTION ACTIVATED SUCCESSFULLY (1 month)\n`);
    } else {
      console.log('❌ Subscription not found');
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

activateSubscription();
