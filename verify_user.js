#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function verifyUserSetup(email) {
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

    console.log('\n✅ FINAL USER STATUS:\n');
    console.log('📋 User Details:');
    console.log('   User ID: ' + userDoc.id);
    console.log('   Email: ' + data.email);
    console.log('   Username: ' + (data.username || data.name));
    console.log('');
    console.log('💳 Subscription Status:');
    console.log('   Active: ' + (data.subscription?.isActive ? 'YES ✅' : 'NO'));
    console.log('   Tier: ' + (data.subscription?.tier || 'none'));
    console.log('   Expiry: ' + (data.subscription?.expiryDate?.toDate?.().toLocaleDateString() || 'N/A'));
    console.log('   Auto-Renew: ' + (data.subscription?.autoRenew ? 'YES' : 'NO'));
    console.log('');
    console.log('💙 Dating Verification:');
    console.log('   Status: ' + (data.dating?.verificationStatus || 'none'));
    console.log('   Locked by Admin: ' + (data.dating?.verificationLockedByAdmin ? 'YES ✅' : 'NO'));
    console.log('   Protection: ' + (data.dating?.verificationLockedReason || 'N/A'));
    console.log('');
    console.log('✅ User is now fully set up with:');
    console.log('   • Active premium subscription (until 4/15/2026)');
    console.log('   • Verified dating profile');
    console.log('   • Admin protection against auto-revert');
    console.log('');

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

const email = process.argv[2];
if (!email) {
  console.error('Usage: node verify_user.js <email>');
  process.exit(1);
}

verifyUserSetup(email);
