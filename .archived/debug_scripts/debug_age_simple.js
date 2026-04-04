#!/usr/bin/env node

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function debugAge(email) {
  try {
    const db = admin.firestore();
    
    const snapshot = await db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (snapshot.empty) {
      console.log('❌ User not found');
      process.exit(1);
    }

    const userData = snapshot.docs[0].data();
    
    console.log('\n📊 AGE FIELD STATUS:');
    console.log('   Root age:', userData.age ?? 'NULL');
    console.log('   dating.profile.age:', userData.dating?.profile?.age ?? 'NULL');
    console.log('   nexus2.profile.age:', userData.nexus2?.profile?.age ?? 'NULL');
    
    console.log('\n📅 DATING PROFILE KEYS:');
    console.log('   Keys:', Object.keys(userData.dating?.profile || {}));
    
    console.log('\n📝 DATING PROFILE DATA:');
    const prof = userData.dating?.profile || {};
    console.log('   gender:', prof.gender);
    console.log('   city:', prof.city);
    console.log('   country:', prof.country);
    console.log('   age:', prof.age);
    
    console.log('\n📂 VERIFICATION STATE:');
    console.log('   verificationStatus:', userData.dating?.verificationStatus);
    console.log('   profileCompleted:', userData.dating?.profileCompleted);

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

debugAge(process.argv[2]);
