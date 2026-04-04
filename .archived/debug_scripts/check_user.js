#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function checkUser(email) {
  try {
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
    const data = userDoc.data();

    console.log('\n📋 User Details:');
    console.log('   User ID: ' + userDoc.id);
    console.log('   Email: ' + data.email);
    console.log('   Username: ' + (data.username || data.name));
    console.log('   Created: ' + (data.createdAt?.toDate?.() || data.createdAt));
    console.log('');
    console.log('💳 Subscription Status:');
    console.log('   Active: ' + (data.subscription?.isActive || false));
    console.log('   Tier: ' + (data.subscription?.tier || 'none'));
    console.log('   Expiry: ' + (data.subscription?.expiryDate?.toDate?.() || 'N/A'));
    console.log('');
    console.log('💙 Dating Details:');
    console.log('   Verification Status: ' + (data.dating?.verificationStatus || 'none'));
    console.log('   Locked By Admin: ' + (data.dating?.verificationLockedByAdmin || false));
    console.log('');

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

const email = process.argv[2];
if (!email) {
  console.error('Usage: node check_user.js <email>');
  process.exit(1);
}

checkUser(email);
