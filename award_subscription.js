#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

(async () => {
  try {
    const snapshot = await db.collection('users').where('email', '==', '20funmigloria@gmail.com').limit(1).get();
    
    if (snapshot.empty) {
      console.log('❌ User not found');
      process.exit(1);
    }

    const userDoc = snapshot.docs[0];
    const userId = userDoc.id;
    
    const expiryDate = new Date('2026-04-20');
    const startDate = new Date();

    console.log('📝 Awarding subscription to user...');
    console.log('User ID:', userId);
    console.log('Email: 20funmigloria@gmail.com');
    console.log('Start Date:', startDate.toISOString());
    console.log('Expiry Date:', expiryDate.toISOString());
    
    await userDoc.ref.update({
      subscription: {
        isActive: true,
        tier: 'monthly_premium',
        startDate: startDate,
        expiryDate: expiryDate,
        autoRenew: true,
        revenueCatCustomerId: null,
        revenueCatSubscriptionId: null
      },
      onPremium: true,
      subExpDate: expiryDate,
      entitledUser: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('');
    console.log('✅ SUCCESS! Subscription activated for 20funmigloria@gmail.com');
    console.log('   Tier: monthly_premium');
    console.log('   Expires: April 20, 2026');
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
})();
