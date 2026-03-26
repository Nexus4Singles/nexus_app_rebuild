#!/usr/bin/env node

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function deepSearchNullAge() {
  try {
    const db = admin.firestore();
    
    const startTime = Date.now();
    let nullAgeUsers = [];
    let totalUsers = 0;
    let scannedUsers = 0;
    const batchSize = 100;
    let lastDoc = null;

    console.log('🔍 Scanning all users with profileCompleted=true for NULL ages...\n');

    let hasMore = true;
    let batchNum = 0;

    while (hasMore && scannedUsers < 500) {
      batchNum++;
      let query = db
        .collection('users')
        .where('dating.profileCompleted', '==', true)
        .limit(batchSize);

      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const snapshot = await query.get();

      if (snapshot.empty) {
        hasMore = false;
        break;
      }

      snapshot.forEach(doc => {
        scannedUsers++;
        const data = doc.data();
        const age = data.dating?.profile?.age;
        
        if (age === null || age === undefined) {
          nullAgeUsers.push({
            uid: doc.id,
            email: data.email,
            name: data.dating?.profile?.name || data.username,
            created: data.dating?.createdAt?.toDate?.() || 'N/A',
            status: data.dating?.verificationStatus,
            schemaVersion: data.schemaVersion
          });
          console.log(`  [${scannedUsers}] Found NULL age: ${data.email}`);
        }
      });

      lastDoc = snapshot.docs[snapshot.docs.length - 1];
      console.log(`  Batch ${batchNum}: Scanned ${snapshot.size} users (total: ${scannedUsers})`);

      if (snapshot.size < batchSize) {
        hasMore = false;
      }
    }

    const duration = ((Date.now() - startTime) / 1000).toFixed(1);
    
    console.log(`\n✅ SCAN COMPLETE (${duration}s)\n`);
    console.log(`   Total scanned: ${scannedUsers}`);
    console.log(`   NULL age found: ${nullAgeUsers.length}`);
    
    if (nullAgeUsers.length > 0) {
      console.log(`\n📋 Users with NULL ages:`);
      nullAgeUsers.forEach((user, i) => {
        const isTarget = user.email === 'khadilawal8@gmail.com' ? ' ← TARGET' : '';
        console.log(`${i+1}. ${user.email}${isTarget}`);
        console.log(`   Name: ${user.name}`);
        console.log(`   Status: ${user.status}`);
        console.log(`   Created: ${user.created}`);
      });
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

deepSearchNullAge();
