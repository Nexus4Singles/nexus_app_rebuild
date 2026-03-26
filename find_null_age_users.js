#!/usr/bin/env node

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function findNullAgeUsers() {
  try {
    const db = admin.firestore();
    
    // Query all v2 users with profileCompleted but age: null
    const snapshot = await db
      .collection('users')
      .where('schemaVersion', '==', 2)
      .where('dating.profileCompleted', '==', true)
      .limit(50)
      .get();

    console.log(`\nFound ${snapshot.size} v2 users with completed profiles. Checking for null ages...\n`);

    let nullAgeCount = 0;
    const nullAgeUsers = [];

    snapshot.forEach(doc => {
      const data = doc.data();
      const age = data.dating?.profile?.age;
      if (age === null || age === undefined) {
        nullAgeCount++;
        nullAgeUsers.push({
          uid: doc.id,
          email: data.email,
          name: data.dating?.profile?.name || data.username,
          createdAt: data.dating?.createdAt?.toDate?.() || data.dating?.createdAt,
          verificationStatus: data.dating?.verificationStatus,
          age: age
        });
      }
    });

    console.log(`📊 RESULTS:`);
    console.log(`   Total v2 users checked: ${snapshot.size}`);
    console.log(`   Users with NULL age: ${nullAgeCount}`);
    
    if (nullAgeUsers.length > 0) {
      console.log(`\n📋 Users with NULL age:`);
      nullAgeUsers.forEach((user, i) => {
        console.log(`\n${i+1}. ${user.name || 'Unknown'}`);
        console.log(`   Email: ${user.email}`);
        console.log(`   UID: ${user.uid}`);
        console.log(`   Status: ${user.verificationStatus}`);
        console.log(`   Created: ${user.createdAt}`);
      });
    }

    // Check if khadilawal8@gmail.com is in the list
    const targetUser = nullAgeUsers.find(u => u.email === 'khadilawal8@gmail.com');
    if (targetUser) {
      console.log(`\n✓ Target user khadilawal8@gmail.com found in NULL age list`);
      console.log(`  This is ONE of ${nullAgeCount} affected users`);
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

findNullAgeUsers();
