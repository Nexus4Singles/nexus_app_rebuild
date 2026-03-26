#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function debugAgeIssue(email) {
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

    console.log('\n🔍 FULL USER DOCUMENT:');
    console.log(JSON.stringify(data, null, 2));
    
    console.log('\n📊 AGE FIELD ANALYSIS:');
    console.log('   Root age:', data.age ?? 'MISSING');
    console.log('   dating.profile.age:', data.dating?.profile?.age ?? 'MISSING');
    console.log('   nexus2.profile.age:', data.nexus2?.profile?.age ?? 'MISSING');
    
    console.log('\n📅 DATING PROFILE:');
    console.log(JSON.stringify(data.dating?.profile || {}, null, 2));

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

debugAgeIssue(process.argv[2]);
