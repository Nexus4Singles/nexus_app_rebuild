const admin = require('firebase-admin');
const https = require('https');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function migrateV1UserToV2() {
  const email = 'Adeoluwadavidadewale2014@gmail.com';
  
  console.log(`\n=== MIGRATING V1 USER TO V2 SUBSCRIPTION ===\n`);
  console.log(`Email: ${email}\n`);

  try {
    // 1. Find user by email
    console.log('📋 Looking up user by email...');
    const usersSnapshot = await db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.error(`❌ User with email ${email} not found`);
      process.exit(1);
    }

    const userDoc = usersSnapshot.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();
    
    console.log(`✓ User found: ${userId}`);
    console.log(`  Email: ${userData.email}`);
    console.log(`  Username: ${userData.username || userData.name || 'N/A'}\n`);

    // 2. Check current subscription structure
    console.log('🔍 Checking subscription structure...\n');
    
    const hasV2Structure = userData.subscription && typeof userData.subscription === 'object';
    const hasV1Fields = userData.onPremium === true || (userData.subExpDate !== undefined);
    
    console.log(`V2 Structure (subscription object): ${hasV2Structure ? '✓ EXISTS' : '✗ MISSING'}`);
    console.log(`V1 Fields (onPremium/subExpDate): ${hasV1Fields ? '✓ EXISTS' : '✗ MISSING'}\n`);

    if (hasV2Structure) {
      const sub = userData.subscription;
      console.log('📊 Current V2 Subscription:');
      console.log(`  - isActive: ${sub.isActive}`);
      console.log(`  - tier: ${sub.tier}`);
      console.log(`  - expiryDate: ${sub.expiryDate?.toDate?.() || sub.expiryDate}`);
      console.log(`\n⚠️  User already has V2 structure. Nothing to migrate.\n`);
      process.exit(0);
    }

    if (!hasV1Fields) {
      console.log('❌ User has neither V1 nor V2 subscription. Nothing to migrate.\n');
      process.exit(1);
    }

    // 3. Display V1 structure
    console.log('📊 Current V1 Subscription:');
    console.log(`  - onPremium: ${userData.onPremium}`);
    console.log(`  - subExpDate: ${userData.subExpDate?.toDate?.() || userData.subExpDate}`);
    console.log(`  - entitledUser: ${userData.entitledUser}\n`);

    // 4. Build V2 structure from V1 fields
    console.log('🔄 Migrating to V2 structure...\n');
    
    const expiryDate = userData.subExpDate;
    if (!expiryDate) {
      console.error('❌ User has no subExpDate to migrate. Cannot create V2 subscription.');
      process.exit(1);
    }

    // Convert expiry date to proper format if it's a Timestamp
    let expiryTimestamp = expiryDate;
    if (expiryDate.toDate) {
      expiryTimestamp = expiryDate; // Already a Timestamp
    } else if (typeof expiryDate === 'string') {
      expiryTimestamp = admin.firestore.Timestamp.fromDate(new Date(expiryDate));
    } else if (expiryDate instanceof Date) {
      expiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);
    }

    const v2Subscription = {
      isActive: true,
      tier: 'monthly_premium', // Default tier for v1 premium users
      startDate: userData.startDate || admin.firestore.Timestamp.now(),
      expiryDate: expiryTimestamp,
      autoRenew: true,
      revenueCatCustomerId: null,
      revenueCatSubscriptionId: null,
    };

    // 5. Update user document with V2 structure (keep V1 for backward compatibility)
    const updateData = {
      subscription: v2Subscription,
      // Keep V1 fields for backward compatibility
      onPremium: true,
      subExpDate: expiryTimestamp,
      entitledUser: true,
      migratedToV2At: admin.firestore.Timestamp.now(),
    };

    await userDoc.ref.update(updateData);
    console.log('✓ Updated user document with V2 subscription\n');

    // 6. Create audit log
    await userDoc.ref.collection('audit_log').add({
      action: 'v1_to_v2_subscription_migration',
      reason: 'v1_legacy_user_premium_access_fix',
      migratedBy: 'admin_script',
      timestamp: admin.firestore.Timestamp.now(),
      details: {
        previousSchema: 'v1 (onPremium, subExpDate)',
        newSchema: 'v2 (subscription object)',
        tier: 'monthly_premium',
        expiryDate: expiryDate.toDate?.() || expiryDate,
        notes: 'User was unable to access premium features with v1 schema'
      }
    });
    console.log('✓ Created migration audit log\n');

    // 7. Verify migration
    console.log('✅ VERIFICATION\n');
    const updatedUserDoc = await userDoc.ref.get();
    const updatedData = updatedUserDoc.data();
    
    console.log('V2 Subscription structure now present:');
    const sub = updatedData.subscription;
    console.log(`  - isActive: ${sub.isActive}`);
    console.log(`  - tier: ${sub.tier}`);
    console.log(`  - expiryDate: ${sub.expiryDate.toDate()}`);
    console.log(`  - autoRenew: ${sub.autoRenew}`);
    
    console.log('\nV1 fields maintained for backward compatibility:');
    console.log(`  - onPremium: ${updatedData.onPremium}`);
    console.log(`  - subExpDate: ${updatedData.subExpDate.toDate()}`);
    console.log(`  - entitledUser: ${updatedData.entitledUser}`);

    console.log(`\n✅ MIGRATION COMPLETE`);
    console.log(`User ${email} can now access premium features in v2 app\n`);

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

migrateV1UserToV2();
