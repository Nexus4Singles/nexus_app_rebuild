#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

(async () => {
  const email = 'oharisimudi@gmail.com';
  const snapshot = await db.collection('users').where('email', '==', email).limit(1).get();
  
  if (snapshot.empty) {
    console.log('User not found');
    process.exit(1);
  }

  const userDoc = snapshot.docs[0];
  const userData = userDoc.data();
  
  const expiryDate = new Date('2026-04-20');

  console.log('Activating subscription...');
  console.log('User:', userData.name || userData.username);
  console.log('Email:', email);
  console.log('Expiry: April 20, 2026');
  
  await userDoc.ref.update({
    // NEW format (modern)
    subscription: {
      isActive: true,
      tier: 'monthly_premium',
      startDate: new Date(),
      expiryDate: expiryDate,
      autoRenew: true,
      revenueCatCustomerId: null,
      revenueCatSubscriptionId: null,
      validatedBy: 'manual_activation'
    },
    // LEGACY format (required for app to recognize subscription on all code paths)
    onPremium: true,
    subExpDate: expiryDate,
    entitledUser: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log('\nSUCCESS: Subscription activated for ' + email);
  process.exit(0);
})();
