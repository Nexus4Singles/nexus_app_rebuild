const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function awardFreshSubscription() {
  const email = 'Adeoluwadavidadewale2014@gmail.com';
  
  console.log(`\n=== AWARDING FRESH SUBSCRIPTION ===\n`);
  console.log(`Email: ${email}\n`);

  try {
    // 1. Find user by email
    console.log('📋 Looking up user...');
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
    const userId = userDoc.id;
    const userData = userDoc.data();
    
    console.log(`✓ User found: ${userId}`);
    console.log(`  Username: ${userData.username || userData.name}\n`);

    // 2. Set expiry to 1 month from today
    const expiryDate = new Date();
    expiryDate.setMonth(expiryDate.getMonth() + 1);
    const expiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);

    console.log(`🔄 Awarding 1-month subscription...\n`);

    // 3. Create V2 subscription object
    const v2Subscription = {
      isActive: true,
      tier: 'monthly_premium',
      startDate: admin.firestore.Timestamp.now(),
      expiryDate: expiryTimestamp,
      autoRenew: true,
      revenueCatCustomerId: null,
      revenueCatSubscriptionId: null,
    };

    // 4. Update user with fresh subscription
    const updateData = {
      subscription: v2Subscription,
      // Maintain V1 fields for backward compatibility
      onPremium: true,
      subExpDate: expiryTimestamp,
      entitledUser: true,
      updatedAt: admin.firestore.Timestamp.now(),
    };

    await userDoc.ref.update(updateData);
    console.log('✓ Subscription awarded\n');

    // 5. Create audit log
    await userDoc.ref.collection('audit_log').add({
      action: 'subscription_awarded',
      tier: 'monthly_premium',
      expiryDate: expiryDate,
      reason: 'v1_user_expired_subscription_renewal',
      activatedBy: 'admin_script',
      timestamp: admin.firestore.Timestamp.now(),
      details: {
        previousExpiry: userData.subExpDate?.toDate?.() || userData.subExpDate,
        newExpiry: expiryDate.toISOString(),
        duration: '1 month',
        notes: 'V1 legacy user subscription was expired, awarded fresh subscription for premium access'
      }
    });
    console.log('✓ Audit log created\n');

    // 6. Verify
    console.log('✅ VERIFICATION\n');
    const updatedUserDoc = await userDoc.ref.get();
    const updatedData = updatedUserDoc.data();
    
    const sub = updatedData.subscription;
    console.log('V2 Subscription:');
    console.log(`  - isActive: ${sub.isActive}`);
    console.log(`  - tier: ${sub.tier}`);
    console.log(`  - startDate: ${sub.startDate.toDate()}`);
    console.log(`  - expiryDate: ${sub.expiryDate.toDate()}`);
    console.log(`  - autoRenew: ${sub.autoRenew}`);
    
    console.log('\nV1 Fields (backward compat):');
    console.log(`  - onPremium: ${updatedData.onPremium}`);
    console.log(`  - subExpDate: ${updatedData.subExpDate.toDate()}`);
    console.log(`  - entitledUser: ${updatedData.entitledUser}`);

    console.log(`\n✅ FRESH SUBSCRIPTION AWARDED`);
    console.log(`User: ${email}`);
    console.log(`Expires: ${expiryDate.toISOString()}`);
    console.log(`Can now access premium features\n`);

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

awardFreshSubscription();
