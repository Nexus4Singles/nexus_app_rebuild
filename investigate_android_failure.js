#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function investigateAndroidUser() {
  const db = admin.firestore();
  
  console.log('\n📱 INVESTIGATING ANDROID SUBSCRIPTION FAILURE\n');
  console.log('User: tosgirl4christ@gmail.com\n');
  
  // Find user
  const usersSnapshot = await db
    .collection('users')
    .where('email', '==', 'tosgirl4christ@gmail.com')
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    console.log('❌ User not found in Firestore');
    process.exit(1);
  }

  const userDoc = usersSnapshot.docs[0];
  const userId = userDoc.id;
  const userData = userDoc.data();
  
  console.log(`✅ Found user: ${userId}`);
  console.log(`   Name: ${userData.username || userData.name}`);
  console.log(`   Email: ${userData.email}`);
  
  console.log('\n═══════════════════════════════════════════════════════════');
  console.log('SECTION 1: CURRENT SUBSCRIPTION STATE');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  console.log('subscription field:');
  if (userData.subscription) {
    console.log(JSON.stringify(userData.subscription, null, 2));
  } else {
    console.log('❌ NO subscription field exists');
  }
  
  console.log('\nLegacy fields:');
  console.log(`  onPremium: ${userData.onPremium}`);
  console.log(`  entitledUser: ${userData.entitledUser}`);
  console.log(`  subExpDate: ${userData.subExpDate}`);
  
  console.log('\n═══════════════════════════════════════════════════════════');
  console.log('SECTION 2: TRANSACTION HISTORY');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  // Check transactions subcollection
  const transactionsRef = userDoc.ref.collection('transactions');
  const transactionSnapshot = await transactionsRef.get();
  
  if (transactionSnapshot.empty) {
    console.log('❌ NO transaction records found');
  } else {
    console.log(`✅ Found ${transactionSnapshot.size} transaction(s):\n`);
    transactionSnapshot.forEach((doc, index) => {
      const tx = doc.data();
      console.log(`Transaction ${index + 1}: ${doc.id}`);
      console.log(JSON.stringify(tx, null, 2));
      console.log('');
    });
  }
  
  console.log('═══════════════════════════════════════════════════════════');
  console.log('SECTION 3: NOTIFICATIONS SUBCOLLECTION');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  // Check notifications - might show subscription events
  const notificationsRef = userDoc.ref.collection('notifications');
  const notificationSnapshot = await notificationsRef.get();
  
  if (notificationSnapshot.empty) {
    console.log('❌ NO notifications found');
  } else {
    console.log(`✅ Found ${notificationSnapshot.size} notification(s):\n`);
    notificationSnapshot.forEach((doc, index) => {
      const notif = doc.data();
      if (notif.type?.includes('subscription') || notif.type?.includes('purchase')) {
        console.log(`Notification ${index + 1}: ${doc.id}`);
        console.log(`  Type: ${notif.type}`);
        console.log(`  Title: ${notif.title}`);
        console.log(`  Created: ${notif.createdAt?.toDate?.()?.toISOString()}`);
        console.log('');
      }
    });
  }
  
  console.log('═══════════════════════════════════════════════════════════');
  console.log('SECTION 4: AUDIT LOG');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  // Check audit logs
  const auditRef = userDoc.ref.collection('auditLog');
  const auditSnapshot = await auditRef.orderBy('timestamp', 'desc').limit(10).get();
  
  if (auditSnapshot.empty) {
    console.log('❌ NO audit logs found');
  } else {
    console.log(`✅ Found ${auditSnapshot.size} audit log(s):\n`);
    auditSnapshot.forEach((doc, index) => {
      const log = doc.data();
      console.log(`Log ${index + 1}:`);
      console.log(`  Action: ${log.action}`);
      console.log(`  Timestamp: ${log.timestamp?.toDate?.()?.toISOString()}`);
      console.log(`  Details: ${JSON.stringify({provider: log.provider, tier: log.tier, status: log.status}, null, 2)}`);
      console.log('');
    });
  }
  
  console.log('═══════════════════════════════════════════════════════════');
  console.log('SUMMARY & ROOT CAUSE ANALYSIS');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  const hasSubscription = userData.subscription?.isActive;
  const hasTransactions = transactionSnapshot.size > 0;
  const onPremium = userData.onPremium;
  
  console.log(`Has subscription record: ${hasSubscription ? '✅ YES' : '❌ NO'}`);
  console.log(`Has transaction records: ${hasTransactions ? '✅ YES' : '❌ NO'}`);
  console.log(`onPremium flag: ${onPremium ? '✅ YES' : '❌ NO'}`);
  
  if (!hasTransactions) {
    console.log('\n🔴 ROOT CAUSE: No transaction found');
    console.log('   This means either:');
    console.log('   1. Purchase was never sent to Firebase Functions');
    console.log('   2. Client-side purchase validation failed');
    console.log('   3. Network error prevented transaction upload');
  } else if (hasTransactions && !hasSubscription) {
    console.log('\n🔴 ROOT CAUSE: Transaction exists but subscription was NOT created');
    console.log('   This means Firebase Cloud Function did not execute properly');
    console.log('   Check cloud function logs for validation errors');
  }
  
  process.exit(0);
}

investigateAndroidUser().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
