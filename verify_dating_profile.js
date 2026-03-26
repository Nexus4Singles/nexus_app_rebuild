#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function verifyUserProfile(email) {
  try {
    console.log(`\n✅ Verifying dating profile for: ${email}`);
    
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
    console.log(`   Current Status: ${userData.dating?.verificationStatus || 'none'}`);

    const now = admin.firestore.FieldValue.serverTimestamp();

    await db.collection('users').doc(userId).update({
      'dating.verificationStatus': 'verified',
      'dating.verifiedAt': now,
      'dating.verifiedBy': 'admin_manual_verification',
      'dating.verificationCheckedAt': now,
    });

    console.log('\n✅ Dating profile verified by admin');
    console.log('   User: ' + userId);
    console.log('   Email: ' + email);
    console.log('   Status: verified');
    console.log('');

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

const email = process.argv[2];
if (!email) {
  console.error('Usage: node verify_dating_profile.js <email>');
  process.exit(1);
}

verifyUserProfile(email);
