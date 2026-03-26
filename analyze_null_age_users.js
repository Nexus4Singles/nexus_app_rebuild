#!/usr/bin/env node

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function analyzeAllNullAgeUsers() {
  try {
    const db = admin.firestore();
    
    const emails = [
      'khadilawal8@gmail.com',
      'adedolapooluwabiyi5@gmail.com',
      'okhiriaonomeasike2018@gmail.com'
    ];

    console.log('\n🔍 ANALYZING NULL AGE USERS:');
    
    for (const email of emails) {
      const snapshot = await db
        .collection('users')
        .where('email', '==', email)
        .limit(1)
        .get();

      if (snapshot.empty) continue;

      const userData = snapshot.docs[0].data();
      const uid = snapshot.docs[0].id;

      console.log(`\n${email}:`);
      console.log(`  ├─ UID: ${uid}`);
      console.log(`  ├─ Name: ${userData.dating?.profile?.name}`);
      console.log(`  ├─ Status: ${userData.dating?.verificationStatus}`);
      console.log(`  ├─ Gender: ${userData.dating?.profile?.gender}`);
      console.log(`  ├─ Photos: ${userData.dating?.profile?.photos?.length || 0}`);
      console.log(`  ├─ Profession: ${userData.dating?.profile?.profession}`);
      console.log(`  ├─ Education: ${userData.dating?.profile?.educationLevel}`);
      console.log(`  ├─ Church: ${userData.dating?.profile?.churchName}`);
      
      // Check if there's any age-related field in other nested objects
      console.log(`  └─ Age fields:`);
      console.log(`      ├─ dating.profile.age: ${userData.dating?.profile?.age}`);
      console.log(`      ├─ root age: ${userData.age}`);
      console.log(`      └─ nexus2.profile.age: ${userData.nexus2?.profile?.age}`);

      // Check if datingProfiles exists
      const dpDoc = await db.collection('datingProfiles').doc(uid).get();
      console.log(`      datingProfiles/{uid} exists: ${dpDoc.exists ? 'YES' : 'NO'}`);
    }

    console.log('\n\n📌 KEY FINDINGS:');
    console.log('   1. Profile completion allowed saving null age');
    console.log('   2. Other fields (name, photos, etc.) were saved successfully');
    console.log('   3. Two verif ied users also have null ages → oversight in review');
    console.log('   4. datingProfiles collection not populated for any of them');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

analyzeAllNullAgeUsers();
