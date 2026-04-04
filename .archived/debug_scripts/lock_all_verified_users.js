#!/usr/bin/env node

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function lockAllVerifiedUsers() {
  try {
    const db = admin.firestore();
    
    console.log(`\n🔍 Finding all users with verified dating profiles...`);
    
    // Query all users with verificationStatus = 'verified'
    const usersSnapshot = await db
      .collection('users')
      .where('dating.verificationStatus', '==', 'verified')
      .get();

    if (usersSnapshot.empty) {
      console.log(`✅ No verified users found to lock`);
      process.exit(0);
    }

    const totalUsers = usersSnapshot.size;
    console.log(`✅ Found ${totalUsers} verified users to lock`);

    // Batch update in groups of 500 (Firestore batch limit)
    const batchSize = 500;
    let processedCount = 0;
    let errorCount = 0;

    for (let i = 0; i < usersSnapshot.docs.length; i += batchSize) {
      const batch = db.batch();
      const batchDocs = usersSnapshot.docs.slice(i, i + batchSize);

      for (const userDoc of batchDocs) {
        const userData = userDoc.data();
        batch.update(userDoc.ref, {
          'dating.verificationLockedByAdmin': true,
          'dating.verificationLockedAt': admin.firestore.FieldValue.serverTimestamp(),
          'dating.verificationLockedReason': 'Batch lock: prevent auto-revert on profile updates',
        });
      }

      try {
        await batch.commit();
        processedCount += batchDocs.length;
        console.log(`✅ Batch committed: ${processedCount}/${totalUsers} users locked`);
      } catch (error) {
        errorCount += batchDocs.length;
        console.error(`❌ Batch failed: ${error.message}`);
      }
    }

    console.log(`\n📊 Summary:`);
    console.log(`   Total processed: ${processedCount}`);
    console.log(`   Errors: ${errorCount}`);
    console.log(`   Success: ${processedCount - errorCount}`);

    if (errorCount === 0) {
      console.log(`\n✅ ALL VERIFIED USERS LOCKED - They won't auto-revert on profile updates!`);
    }

    process.exit(0);
  } catch (error) {
    console.error(`\n❌ Error: ${error.message}`);
    console.error(error);
    process.exit(1);
  }
}

// Check for --force flag
const forceRun = process.argv[2] === '--force';

if (!forceRun) {
  console.log(`
╔════════════════════════════════════════════════════════════╗
║  Batch Lock All Verified Users                             ║
║  Prevents auto-revert from verified → unverified           ║
║  on profile updates                                        ║
╚════════════════════════════════════════════════════════════╝

⚠️  This will lock ALL verified users in Firestore.

Usage: node lock_all_verified_users.js --force
`);
  process.exit(0);
}

lockAllVerifiedUsers();
