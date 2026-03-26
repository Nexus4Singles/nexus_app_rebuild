const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function activateSubscription() {
  const userId = 'NkQa8IaOTlXgqTQGaukysv2q0jk2';
  const email = 'oladelesamuel0907@gmail.com';
  
  // User's RevenueCat subscription expires 2026-04-24, so match that
  const expiryDate = new Date('2026-04-24T06:46:05Z');
  
  console.log(`\n=== ACTIVATING SUBSCRIPTION ===`);
  console.log(`User ID: ${userId}`);
  console.log(`Email: ${email}`);
  console.log(`Expiry: ${expiryDate.toISOString()}\n`);

  try {
    // 1. Create subscription record in subcollection
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

    // 2. Update user doc with subscription fields
    const userUpdate = {
      'subscription': subscriptionRecord,
      'onPremium': true,
      'subExpDate': expiryDate,
      'entitledUser': true,
      'updatedAt': admin.firestore.Timestamp.now(),
    };

    await db.collection('users').doc(userId).update(userUpdate);
    console.log('✓ Updated user doc with subscription fields');

    // 3. Create audit log
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
        notes: 'Android race condition: Purchases.logIn() not called before purchase'
      }
    });
    console.log('✓ Created audit log entry');

    // 4. Verify
    const subDoc = await db.collection('users').doc(userId).collection('subscription').doc('current').get();
    const userData = await db.collection('users').doc(userId).get();

    console.log('\n=== VERIFICATION ===');
    console.log(`Subscription record exists: ${subDoc.exists ? '✓' : '✗'}`);
    if (subDoc.exists) {
      const sub = subDoc.data();
      console.log(`  - Tier: ${sub.tier}`);
      console.log(`  - isActive: ${sub.isActive}`);
      console.log(`  - Expires: ${sub.expiryDate.toDate()}`);
      console.log(`  - Verified: ${sub.verificationStatus}`);
    }

    console.log(`User doc has subscription field: ${userData.data().subscription ? '✓' : '✗'}`);
    if (userData.data().subscription) {
      console.log(`  - onPremium: ${userData.data().onPremium}`);
      console.log(`  - entitledUser: ${userData.data().entitledUser}`);
    }

    console.log('\n✅ SUBSCRIPTION ACTIVATED SUCCESSFULLY');
    console.log(`User ${userId} (${email}) can now use premium features`);

  } catch (error) {
    console.error('❌ Error activating subscription:', error.message);
    process.exit(1);
  }
}

activateSubscription();
