#!/usr/bin/env node

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function checkReviewPack(email) {
  try {
    const db = admin.firestore();
    
    // Get user
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
    
    console.log('\n📋 DATING REVIEW PACK:');
    const reviewPack = userData.dating?.reviewPack;
    if (reviewPack) {
      console.log('   Submitted At:', reviewPack.submittedAt?.toDate?.() || reviewPack.submittedAt);
      console.log('   Photos count:', Array.isArray(reviewPack.photoUrls) ? reviewPack.photoUrls.length : 'N/A');
      console.log('   Audio count:', Array.isArray(reviewPack.audioUrls) ? reviewPack.audioUrls.length : 'N/A');
      console.log('   Full review pack:');
      console.log(JSON.stringify(reviewPack, null, 2));
    } else {
      console.log('   ❌ No review pack found');
    }
    
    console.log('\n📂 FULL DATING OBJECT:');
    console.log(JSON.stringify(userData.dating || {}, null, 2));

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

checkReviewPack(process.argv[2]);
