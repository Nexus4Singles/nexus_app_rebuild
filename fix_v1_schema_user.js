#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function fixV1SchemaUser() {
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
  
  console.log('\n🔧 FIXING V1 SCHEMA FOR: sunkykush007@gmail.com\n');
  console.log(`User ID: ${userId}`);
  
  const subscription = userData.subscription || {};
  const subExpDate = userData.subExpDate;
  
  // Convert string dates to Timestamps
  let fixedSubscription = { ...subscription };
  let fixedSubExpDate = null;
  
  // Fix subscription.expiryDate
  if (subscription.expiryDate && typeof subscription.expiryDate === 'string') {
    const dateObj = new Date(subscription.expiryDate);
    fixedSubscription.expiryDate = admin.firestore.Timestamp.fromDate(dateObj);
    console.log(`✅ Converting subscription.expiryDate from string to Timestamp`);
    console.log(`   Was: "${subscription.expiryDate}"`);
    console.log(`   Now: Timestamp(${dateObj.toISOString()})`);
  }
  
  // Fix subscription.startDate if it's stored as object with _seconds
  if (subscription.startDate && typeof subscription.startDate === 'object' && 
      subscription.startDate._seconds && !subscription.startDate.toDate) {
    const dateObj = new Date(subscription.startDate._seconds * 1000);
    fixedSubscription.startDate = admin.firestore.Timestamp.fromDate(dateObj);
    console.log(`✅ Converting subscription.startDate from raw object to Timestamp`);
  }
  
  // Fix subExpDate
  if (subExpDate && typeof subExpDate === 'string') {
    const dateObj = new Date(subExpDate);
    fixedSubExpDate = admin.firestore.Timestamp.fromDate(dateObj);
    console.log(`✅ Converting subExpDate from string to Timestamp`);
    console.log(`   Was: "${subExpDate}"`);
    console.log(`   Now: Timestamp(${dateObj.toISOString()})`);
  }
  
  // Fix entitledUser from string "null" to true
  let fixedEntitledUser = userData.entitledUser;
  if (userData.entitledUser === 'null' || userData.entitledUser === null) {
    fixedEntitledUser = true;
    console.log(`✅ Converting entitledUser from "${userData.entitledUser}" to true`);
  }
  
  // Update user document
  const updateData = {
    subscription: fixedSubscription,
    entitledUser: fixedEntitledUser,
  };
  
  if (fixedSubExpDate) {
    updateData.subExpDate = fixedSubExpDate;
  }
  
  await userDoc.ref.update(updateData);
  
  console.log(`\n✅ V1 Schema conversion complete!`);
  console.log(`📝 Updated fields in Firestore\n`);
  
  process.exit(0);
}

fixV1SchemaUser().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
