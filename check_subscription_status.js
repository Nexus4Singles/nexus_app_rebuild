#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function checkStatus() {
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

  const userData = usersSnapshot.docs[0].data();
  
  console.log('\n📋 Current Subscription Status:\n');
  console.log(`Email: ${userData.email}`);
  console.log(`Subscription Active: ${userData.subscription?.isActive}`);
  console.log(`Tier: ${userData.subscription?.tier}`);
  console.log(`Expiry Date: ${userData.subscription?.expiryDate?.toDate?.()?.toLocaleDateString() || userData.subscription?.expiryDate}`);
  console.log(`onPremium flag: ${userData.onPremium}`);
  console.log(`entitledUser flag: ${userData.entitledUser}`);
  console.log(`Verified At: ${userData.subscription?.validatedAt?.toDate?.()?.toISOString() || userData.subscription?.validatedAt}`);
  
  process.exit(0);
}

checkStatus().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
