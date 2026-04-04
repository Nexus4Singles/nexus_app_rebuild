const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function activateIOSSubscription() {
  const userId = 'YwCMlX39kcZH3F4WHb53twQsM1q1';
  
  // Set expiry to April 28, 2026
  const expiryDate = new Date('2026-04-28T00:00:00Z');
  const expiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);
  
  console.log(`\n=== ACTIVATING iOS USER SUBSCRIPTION ===\n`);

  try {
    // 1. Get user data
    console.log('📋 Fetching user...');
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.error(`❌ User not found`);
      process.exit(1);
    }

    const userData = userDoc.data();
    const email = userData.email || 'unknown';
    console.log(`✓ User found: ${email}\n`);

    // 2. Create V2 subscription structure
    console.log('📝 Creating V2 subscription structure...');
    const subscriptionRecord = {
      isActive: true,
      tier: 'monthly_premium',
      startDate: admin.firestore.Timestamp.now(),
      expiryDate: expiryTimestamp,
      autoRenew: true,
      revenueCatCustomerId: null,
      revenueCatSubscriptionId: null,
    };

    // 3. Create subcollection document for reference (optional but good practice)
    await userDoc.ref.collection('subscription').doc('current').set(subscriptionRecord);
    console.log('✓ Created subscription/current subcollection document');

    // 4. Update main user document with both V1 and V2 fields
    const userUpdate = {
      'subscription': subscriptionRecord,
      // V1 fields for backward compatibility with old app builds
      'onPremium': true,
      'subExpDate': expiryTimestamp,
      'entitledUser': true,
      'updatedAt': admin.firestore.Timestamp.now(),
    };

    await userDoc.ref.update(userUpdate);
    console.log('✓ Updated user document\n');

    // 5. Create audit log
    await userDoc.ref.collection('audit_log').add({
      action: 'subscription_activated',
      tier: 'monthly_premium',
      expiryDate: expiryDate,
      reason: 'manual_activation_ios_webhook_not_synced',
      activatedBy: 'admin_script',
      timestamp: admin.firestore.Timestamp.now(),
      details: {
        issue: 'iOS user subscribed but subscription did not sync to Firestore',
        possibleCauses: [
          'User is running old build without RevenueCat linking fix',
          'RevenueCat webhook did not fire',
          'Webhook fired but user lookup failed'
        ],
        solution: 'Manual activation with both V1 and V2 schema',
        expiryDate: expiryDate.toISOString(),
        notes: 'User should update app to latest build to avoid this in future'
      }
    });
    console.log('✓ Created audit log\n');

    // 6. Verify
    console.log('✅ VERIFICATION\n');
    const updatedUserDoc = await userDoc.ref.get();
    const updatedData = updatedUserDoc.data();
    
    console.log('V2 Subscription (for current app):');
    const sub = updatedData.subscription;
    console.log(`  - isActive: ${sub.isActive}`);
    console.log(`  - tier: ${sub.tier}`);
    console.log(`  - expiryDate: ${sub.expiryDate.toDate()}`);
    
    console.log('\nV1 Fields (for old app builds):');
    console.log(`  - onPremium: ${updatedData.onPremium}`);
    console.log(`  - subExpDate: ${updatedData.subExpDate.toDate()}`);
    console.log(`  - entitledUser: ${updatedData.entitledUser}`);

    console.log(`\n✅ iOS SUBSCRIPTION ACTIVATED SUCCESSFULLY`);
    console.log(`User: ${email}`);
    console.log(`Expires: April 28, 2026`);
    console.log(`Schema: Both V1 and V2 created for compatibility\n`);

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

activateIOSSubscription();
