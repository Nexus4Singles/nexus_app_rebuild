/**
 * Cleanup Redundant Nested Profile Data
 * 
 * This script removes redundant nested profile data after backup.
 * Deletes dating.profile.*, nexus2.profile.*, and contactInfo.countryOfResidence
 * 
 * IMPORTANT: Run backup_nested_profile_data.js FIRST!
 * 
 * Run with: node scripts/cleanup_nested_profile_data.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('../serviceAccount.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

async function cleanupNestedProfileData() {
  console.log('🧹 Starting cleanup of nested profile data...\n');

  // First verify backup exists
  const backupRef = db.collection('profile_data_backup');
  const backupSnapshot = await backupRef.limit(1).get();
  
  if (backupSnapshot.empty) {
    console.error('❌ ERROR: No backup found in profile_data_backup collection!');
    console.error('   Please run backup_nested_profile_data.js first.');
    process.exit(1);
  }

  console.log('✅ Backup collection verified\n');

  const usersRef = db.collection('users');
  
  let processedCount = 0;
  let cleanedCount = 0;
  let errorCount = 0;
  let skippedCount = 0;

  try {
    const snapshot = await usersRef.get();
    console.log(`📊 Found ${snapshot.size} user documents\n`);

    // Process in batches of 500 (Firestore batch limit)
    const batchSize = 500;
    let batch = db.batch();
    let batchOps = 0;

    for (const doc of snapshot.docs) {
      processedCount++;
      const uid = doc.id;
      const data = doc.data();
      const docRef = usersRef.doc(uid);

      // Check what needs to be deleted
      const hasNestedDating = data.dating?.profile;
      const hasNestedNexus2 = data.nexus2?.profile;
      const hasCountryInContactInfo = data.dating?.contactInfo?.countryOfResidence;

      if (!hasNestedDating && !hasNestedNexus2 && !hasCountryInContactInfo) {
        skippedCount++;
        if (processedCount % 100 === 0) {
          console.log(`  Processed ${processedCount} users (${cleanedCount} cleaned, ${skippedCount} skipped)...`);
        }
        continue;
      }

      try {
        const updates = {};

        // Delete dating.profile.* fields
        if (hasNestedDating) {
          updates['dating.profile'] = FieldValue.delete();
        }

        // Delete nexus2.profile.* fields
        if (hasNestedNexus2) {
          updates['nexus2.profile'] = FieldValue.delete();
        }

        // Delete contactInfo.countryOfResidence (keep root country)
        if (hasCountryInContactInfo) {
          updates['dating.contactInfo.countryOfResidence'] = FieldValue.delete();
        }

        // Add to batch
        batch.update(docRef, updates);
        batchOps++;
        cleanedCount++;

        console.log(`  🧹 Queued cleanup for user ${uid}`);

        // Commit batch if it reaches size limit
        if (batchOps >= batchSize) {
          await batch.commit();
          console.log(`\n  💾 Committed batch of ${batchOps} updates\n`);
          batch = db.batch();
          batchOps = 0;
        }

      } catch (error) {
        errorCount++;
        console.error(`  ❌ Error cleaning user ${uid}:`, error.message);
      }

      if (processedCount % 100 === 0) {
        console.log(`  Processed ${processedCount} users (${cleanedCount} cleaned, ${skippedCount} skipped)...`);
      }
    }

    // Commit remaining batch
    if (batchOps > 0) {
      await batch.commit();
      console.log(`\n  💾 Committed final batch of ${batchOps} updates\n`);
    }

    console.log('\n✅ Cleanup complete!');
    console.log(`   Total users processed: ${processedCount}`);
    console.log(`   Users cleaned: ${cleanedCount}`);
    console.log(`   Users skipped (no nested data): ${skippedCount}`);
    console.log(`   Errors: ${errorCount}`);
    console.log(`\n   ✅ Redundant nested data removed`);
    console.log(`   ✅ Root-level fields preserved`);
    console.log(`   ✅ Backup available in 'profile_data_backup' collection`);

  } catch (error) {
    console.error('❌ Fatal error during cleanup:', error);
    process.exit(1);
  }
}

// Run cleanup
cleanupNestedProfileData()
  .then(() => {
    console.log('\n🎉 Cleanup script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Cleanup script failed:', error);
    process.exit(1);
  });
