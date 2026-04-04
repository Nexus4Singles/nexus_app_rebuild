#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function investigateFlutterwave(email) {
  try {
    console.log('\n🔍 INVESTIGATING FLUTTERWAVE SUBSCRIPTION ISSUE\n');
    console.log('Email: ' + email);
    
    const snapshot = await db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (snapshot.empty) {
      console.log('❌ User not found');
      process.exit(1);
    }

    const userDoc = snapshot.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();

    console.log('User ID: ' + userId);
    console.log('');

    // Check for Flutterwave transaction records
    const transactionsSnapshot = await db
      .collection('users').doc(userId)
      .collection('transactions')
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();

    console.log('📋 TRANSACTION HISTORY:\n');
    if (transactionsSnapshot.empty) {
      console.log('   ❌ No transaction records found in Firestore');
      console.log('   ISSUE: Transactions collection is empty');
      console.log('   This means webhook may not have fired at all.\n');
    } else {
      console.log('   ✅ Found ' + transactionsSnapshot.size + ' transaction(s)\n');
      transactionsSnapshot.forEach(doc => {
        const data = doc.data();
        console.log('   Transaction ID: ' + doc.id);
        console.log('   • Provider: ' + (data.provider || 'N/A'));
        console.log('   • Amount: ' + (data.amount || 'N/A'));
        console.log('   • Status: ' + (data.status || 'N/A'));
        console.log('   • Tier: ' + (data.tier || 'N/A'));
        console.log('   • Product ID: ' + (data.productId || 'N/A'));
        console.log('   • Reference: ' + (data.reference || 'N/A'));
        console.log('   • Created: ' + (data.createdAt?.toDate?.() || data.createdAt));
        console.log('   • Updated: ' + (data.updatedAt?.toDate?.() || data.updatedAt));
        console.log('');
      });
    }

    // Check Flutterwave payment records collection
    const paymentsSnapshot = await db
      .collection('users').doc(userId)
      .collection('flutterwave_payments')
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();

    console.log('💳 FLUTTERWAVE PAYMENTS COLLECTION:\n');
    if (paymentsSnapshot.empty) {
      console.log('   ❌ No Flutterwave payment records found');
    } else {
      console.log('   ✅ Found ' + paymentsSnapshot.size + ' payment record(s)\n');
      paymentsSnapshot.forEach(doc => {
        const data = doc.data();
        console.log('   Reference: ' + doc.id);
        console.log('   • Status: ' + (data.status || 'N/A'));
        console.log('   • Amount: ' + (data.amount || 'N/A'));
        console.log('   • Tier: ' + (data.tier || 'N/A'));
        console.log('   • Product ID: ' + (data.productId || 'N/A'));
        console.log('   • Created: ' + (data.createdAt?.toDate?.() || data.createdAt));
        console.log('');
      });
    }

    // Check current subscription state
    console.log('💳 CURRENT SUBSCRIPTION STATE:\n');
    console.log('   Active: ' + (userData.subscription?.isActive ? 'YES' : 'NO'));
    console.log('   Tier: ' + (userData.subscription?.tier || 'NONE'));
    console.log('   Expiry: ' + (userData.subscription?.expiryDate?.toDate?.() || 'N/A'));
    console.log('   Validated By: ' + (userData.subscription?.validatedBy || 'N/A'));
    console.log('');

    // Check audit logs
    const auditSnapshot = await db
      .collection('users').doc(userId)
      .collection('auditLog')
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();

    console.log('📝 AUDIT LOG:\n');
    if (auditSnapshot.empty) {
      console.log('   ❌ No audit logs found');
    } else {
      auditSnapshot.forEach(doc => {
        const data = doc.data();
        console.log('   • ' + data.action + ' (' + (data.timestamp?.toDate?.() || data.timestamp) + ')');
        if (data.reason) console.log('     Reason: ' + data.reason);
        if (data.provider) console.log('     Provider: ' + data.provider);
      });
    }
    console.log('');

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

const email = process.argv[2];
if (!email) {
  console.error('Usage: node investigate_flutterwave.js <email>');
  process.exit(1);
}

investigateFlutterwave(email);
