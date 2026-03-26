#!/usr/bin/env node

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function debugDatingProfiles(email) {
  try {
    const db = admin.firestore();
    
    // First get the user ID
    const snapshot = await db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (snapshot.empty) {
      console.log('❌ User not found');
      process.exit(1);
    }

    const userId = snapshot.docs[0].id;
    const userData = snapshot.docs[0].data();
    
    console.log(`\n📝 User ID: ${userId}`);
    console.log(`   Email: ${userData.email}`);
    console.log(`   Schema Version: ${userData.schemaVersion}`);
    
    // Check if datingProfiles/{uid} exists
    const datingProfileDoc = await db.collection('datingProfiles').doc(userId).get();
    
    console.log('\n📂 datingProfiles/' + userId + ':');
    if (datingProfileDoc.exists) {
      const dpData = datingProfileDoc.data();
      console.log('   ✅ EXISTS');
      console.log('   Age:', dpData.age ?? 'NULL');
      console.log('   Name:', dpData.name ?? 'NULL');
      console.log('   Gender:', dpData.gender ?? 'NULL');
      console.log('   Photos count:', Array.isArray(dpData.photos) ? dpData.photos.length : 'NULL');
      console.log('\n   Full data:');
      console.log(JSON.stringify(dpData, null, 2));
    } else {
      console.log('   ❌ DOES NOT EXIST');
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

debugDatingProfiles(process.argv[2]);
