#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function lockUserVerification(email) {
  try {
    console.log(`\n🔒 Locking verification for: ${email}`);
    
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

    console.log(`✅ Found user: ${userId}`);
    console.log(`   Name: ${userData.username || userData.name}`);
    console.log(`   Status: ${userData.dating?.verificationStatus || 'none'}`);

    await db.collection('users').doc(userId).update({
      'dating.verificationLockedByAdmin': true,
      'dating.verificationLockedAt': admin.firestore.FieldValue.serverTimestamp(),
      'dating.verificationLockedReason': 'Auto-locked to prevent revert on profile updates',
    });

    console.log('\n✅ Verification locked by admin');
    console.log('   User: ' + userId);
    console.log('   Email: ' + email);
    console.log('   Status: Protected from auto-revert');
    console.log('');

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

const email = process.argv[2];
if (!email) {
  console.error('Usage: node lock_user_verification.js <email>');
  process.exit(1);
}

lockUserVerification(email);
