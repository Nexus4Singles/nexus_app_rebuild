#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function compareUsers() {
  const db = admin.firestore();
  
  console.log('\n═══════════════════════════════════════════════════════════');
  console.log('SECTION 1: iOS USER (SUCCEEDED)');
  console.log('ID: BND1rt57FNMf4B6RIjcFgSWOiwA3');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  const iosDoc = await db.collection('users').doc('BND1rt57FNMf4B6RIjcFgSWOiwA3').get();
  
  if (!iosDoc.exists) {
    console.log('❌ iOS user not found');
    process.exit(1);
  }
  
  const iosData = iosDoc.data();
  console.log(`Name: ${iosData.username || iosData.name}`);
  console.log(`Email: ${iosData.email}`);
  
  console.log('\nSubscription field:');
  if (iosData.subscription) {
    console.log(JSON.stringify(iosData.subscription, null, 2));
  } else {
    console.log('❌ NO subscription field');
  }
  
  // Check transactions
  const iosTransRef = iosDoc.ref.collection('transactions');
  const iosTransSnapshot = await iosTransRef.get();
  
  console.log(`\nTransactions: ${iosTransSnapshot.size}`);
  if (iosTransSnapshot.size > 0) {
    iosTransSnapshot.forEach((doc, idx) => {
      const tx = doc.data();
      console.log(`\n  Transaction ${idx + 1}:`);
      console.log(`    ID: ${doc.id}`);
      console.log(`    Platform/Source: ${tx.source || tx.platform || 'unknown'}`);
      console.log(`    Amount: ${tx.amount}`);
      console.log(`    Currency: ${tx.currency}`);
      console.log(`    Package ID: ${tx.packageId || 'N/A'}`);
      console.log(`    Transaction Date: ${tx.transactionDate?.toDate?.()?.toISOString() || tx.timestamp?.toDate?.()?.toISOString()}`);
      console.log(`    Verified At: ${tx.verifiedAt?.toDate?.()?.toISOString() || 'N/A'}`);
    });
  }
  
  console.log('\n═══════════════════════════════════════════════════════════');
  console.log('SECTION 2: ANDROID USER (FAILED)');
  console.log('Email: tosgirl4christ@gmail.com');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  const androidSnapshot = await db
    .collection('users')
    .where('email', '==', 'tosgirl4christ@gmail.com')
    .limit(1)
    .get();
  
  if (androidSnapshot.empty) {
    console.log('❌ Android user not found');
    process.exit(1);
  }
  
  const androidDoc = androidSnapshot.docs[0];
  const androidData = androidDoc.data();
  const androidId = androidDoc.id;
  
  console.log(`ID: ${androidId}`);
  console.log(`Name: ${androidData.username || androidData.name}`);
  console.log(`Email: ${androidData.email}`);
  
  console.log('\nSubscription field:');
  if (androidData.subscription) {
    console.log(JSON.stringify(androidData.subscription, null, 2));
  } else {
    console.log('❌ NO subscription field');
  }
  
  // Check transactions
  const androidTransRef = androidDoc.ref.collection('transactions');
  const androidTransSnapshot = await androidTransRef.get();
  
  console.log(`\nTransactions: ${androidTransSnapshot.size}`);
  if (androidTransSnapshot.size > 0) {
    androidTransSnapshot.forEach((doc, idx) => {
      const tx = doc.data();
      console.log(`\n  Transaction ${idx + 1}:`);
      console.log(`    ID: ${doc.id}`);
      console.log(`    Platform/Source: ${tx.source || tx.platform || 'unknown'}`);
      console.log(`    Amount: ${tx.amount}`);
      console.log(`    Currency: ${tx.currency}`);
      console.log(`    Package ID: ${tx.packageId || 'N/A'}`);
      console.log(`    Transaction Date: ${tx.transactionDate?.toDate?.()?.toISOString() || tx.timestamp?.toDate?.()?.toISOString()}`);
      console.log(`    Verified At: ${tx.verifiedAt?.toDate?.()?.toISOString() || 'N/A'}`);
    });
  }
  
  console.log('\n═══════════════════════════════════════════════════════════');
  console.log('DETERMINISTIC COMPARISON');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  const iosHasTx = iosTransSnapshot.size > 0;
  const iosHasSub = iosData.subscription?.isActive;
  const androidHasTx = androidTransSnapshot.size > 0;
  const androidHasSub = androidData.subscription?.isActive;
  
  console.log('iOS (SUCCEEDED):');
  console.log(`  Has transactions: ${iosHasTx ? '✅ YES' : '❌ NO'}`);
  console.log(`  Has subscription: ${iosHasSub ? '✅ YES' : '❌ NO'}`);
  
  console.log('\nAndroid (FAILED):');
  console.log(`  Has transactions: ${androidHasTx ? '✅ YES' : '❌ NO'}`);
  console.log(`  Has subscription: ${androidHasSub ? '✅ YES' : '❌ NO'}`);
  
  console.log('\n🔴 ROOT CAUSE ANALYSIS:\n');
  
  if (iosHasTx && !androidHasTx) {
    console.log('The iOS user HAS a transaction record, but Android user DOES NOT.');
    console.log('\nThis is the deterministic difference.');
    console.log('\nPossible reasons:');
    console.log('1. Android app never created a transaction record');
    console.log('2. Android purchase validation failed on client-side');
    console.log('3. Android purchase was rejected by RevenueCat');
    console.log('\nWithout the transaction, the Cloud Function never fires to create');
    console.log('the subscription, so the Android user is stuck.');
  }
  
  process.exit(0);
}

compareUsers().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
