#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function fixIOSSubscription() {
  const db = admin.firestore();
  
  const usersSnapshot = await db
    .collection('users')
    .where('email', '==', 'jenniferizunobi@gmail.com')
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    console.log('❌ User not found');
    process.exit(1);
  }

  const userDoc = usersSnapshot.docs[0];
  const userId = userDoc.id;
  const userData = userDoc.data();
  
  const expiryDate = new Date('2026-04-20');
  
  console.log(`\n🔄 Fixing subscription tier for iOS user...`);
  console.log(`   Email: ${userData.email}`);
  console.log(`   User: ${userId}`);
  console.log(`   Old tier: ${userData.subscription?.tier}`);
  console.log(`   New tier: nexus_premium_v2 (iOS correct tier)`);
  
  const subscriptionData = {
    isActive: true,
    tier: 'nexus_premium_v2',  // Correct iOS tier
    startDate: admin.firestore.FieldValue.serverTimestamp(),
    expiryDate: expiryDate,
    autoRenew: true,
    revenueCatCustomerId: null,
    revenueCatTransactionId: null,
    validatedAt: admin.firestore.FieldValue.serverTimestamp(),
    validatedBy: 'manual_activation_ios_corrected',
    verificationStatus: 'verified',
  };

  await userDoc.ref.update({
    subscription: subscriptionData,
    onPremium: true,
    subExpDate: expiryDate,
    entitledUser: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`\n✅ Subscription CORRECTED for iOS user:`);
  console.log(`   Tier: nexus_premium_v2`);
  console.log(`   Expiry: 2026-04-20`);
  console.log(`   Status: Active\n`);
  
  process.exit(0);
}

fixIOSSubscription().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
