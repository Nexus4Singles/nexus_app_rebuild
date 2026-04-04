#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function investigateUser() {
  const db = admin.firestore();
  
  const usersSnapshot = await db
    .collection('users')
    .where('email', '==', 'sunkykush007@gmail.com')
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    console.log('❌ User not found');
    process.exit(1);
  }

  const userDoc = usersSnapshot.docs[0];
  const userId = userDoc.id;
  const userData = userDoc.data();
  
  console.log('\n📋 USER INVESTIGATION: sunkykush007@gmail.com\n');
  console.log(`User ID: ${userId}`);
  console.log(`Name: ${userData.username || userData.name}`);
  console.log(`Email: ${userData.email}`);
  
  console.log('\n🔍 SUBSCRIPTION DOCUMENT:\n');
  console.log(JSON.stringify(userData.subscription, null, 2));
  
  console.log('\n📊 LEGACY FIELDS:\n');
  console.log(`onPremium: ${userData.onPremium}`);
  console.log(`subExpDate: ${userData.subExpDate?.toDate?.()?.toISOString() || userData.subExpDate}`);
  console.log(`entitledUser: ${userData.entitledUser}`);
  
  console.log('\n🔎 CHECKING TIER RECOGNITION:\n');
  const tier = userData.subscription?.tier;
  console.log(`Stored tier: "${tier}"`);
  console.log(`Tier type: ${typeof tier}`);
  
  // Check if it matches known values
  const knownTiers = ['free', 'monthly_premium', 'monthly', 'Premium', 'nexus_premium', 'monthly_premium_v2', 'nexus_premium_v2'];
  const isKnown = knownTiers.some(t => tier === t || (typeof tier === 'string' && tier.includes(t)));
  console.log(`Matches known tier: ${isKnown ? '✅ Yes' : '❌ No'}`);
  
  console.log('\n⚠️  POTENTIAL ISSUES:\n');
  
  if (!userData.subscription?.isActive) {
    console.log('❌ isActive is false or missing');
  } else {
    console.log('✅ isActive is true');
  }
  
  if (!tier) {
    console.log('❌ Tier is missing');
  } else if (!isKnown) {
    console.log(`❌ Tier value "${tier}" is not recognized by the app`);
  } else {
    console.log('✅ Tier is recognized');
  }
  
  const now = new Date();
  const expiry = userData.subscription?.expiryDate?.toDate?.() || new Date(userData.subscription?.expiryDate);
  if (expiry && expiry < now) {
    console.log(`❌ Subscription expired: ${expiry.toLocaleDateString()}`);
  } else {
    console.log(`✅ Subscription is within valid date range`);
  }
  
  if (!userData.onPremium) {
    console.log('❌ onPremium flag is false or missing - this could prevent the app from recognizing premium access');
  } else {
    console.log('✅ onPremium flag is set to true');
  }
  
  console.log('\n💻 FULL USER OBJECT (subscription + legacy fields):\n');
  const relevantFields = {
    subscription: userData.subscription,
    onPremium: userData.onPremium,
    entitledUser: userData.entitledUser,
    subExpDate: userData.subExpDate,
  };
  console.log(JSON.stringify(relevantFields, null, 2));
  
  process.exit(0);
}

investigateUser().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
