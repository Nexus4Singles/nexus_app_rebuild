/**
 * Backup Nested Profile Data
 * 
 * This script backs up redundant nested profile data before cleanup.
 * Copies dating.profile.* and nexus2.profile.* fields to a backup collection.
 * 
 * Run with: node scripts/backup_nested_profile_data.js
 */

const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin
const serviceAccount = require('../serviceAccount.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function backupNestedProfileData() {
  console.log('🔍 Starting backup of nested profile data...\n');

  const usersRef = db.collection('users');
  const backupRef = db.collection('profile_data_backup');
  
  let processedCount = 0;
  let backedUpCount = 0;
  let errorCount = 0;

  try {
    const snapshot = await usersRef.get();
    console.log(`📊 Found ${snapshot.size} user documents\n`);

    for (const doc of snapshot.docs) {
      processedCount++;
      const uid = doc.id;
      const data = doc.data();

      // Check if document has nested profile data to backup
      const hasNestedDating = data.dating?.profile || data.dating?.contactInfo?.countryOfResidence;
      const hasNestedNexus2 = data.nexus2?.profile;

      if (!hasNestedDating && !hasNestedNexus2) {
        if (processedCount % 100 === 0) {
          console.log(`  Processed ${processedCount} users (${backedUpCount} backed up)...`);
        }
        continue;
      }

      try {
        // Extract nested data to backup
        const backupData = {
          uid: uid,
          backedUpAt: admin.firestore.FieldValue.serverTimestamp(),
          originalData: {}
        };

        if (data.dating?.profile) {
          backupData.originalData.datingProfile = data.dating.profile;
        }

        if (data.dating?.contactInfo?.countryOfResidence) {
          backupData.originalData.datingContactInfoCountry = data.dating.contactInfo.countryOfResidence;
        }

        if (data.nexus2?.profile) {
          backupData.originalData.nexus2Profile = data.nexus2.profile;
        }

        // Also backup root-level fields for reference
        backupData.rootFields = {
          age: data.age,
          city: data.city,
          country: data.country,
          nationality: data.nationality,
          profession: data.profession,
          educationLevel: data.educationLevel,
          churchName: data.churchName,
          hobbies: data.hobbies,
          desiredQualities: data.desiredQualities,
          photos: data.photos,
          profileUrl: data.profileUrl
        };

        await backupRef.doc(uid).set(backupData);
        backedUpCount++;

        console.log(`  ✅ Backed up nested data for user ${uid}`);

      } catch (error) {
        errorCount++;
        console.error(`  ❌ Error backing up user ${uid}:`, error.message);
      }

      if (processedCount % 100 === 0) {
        console.log(`  Processed ${processedCount} users (${backedUpCount} backed up)...`);
      }
    }

    console.log('\n✅ Backup complete!');
    console.log(`   Total users processed: ${processedCount}`);
    console.log(`   Users backed up: ${backedUpCount}`);
    console.log(`   Errors: ${errorCount}`);
    console.log(`\n   Backup stored in 'profile_data_backup' collection`);

  } catch (error) {
    console.error('❌ Fatal error during backup:', error);
    process.exit(1);
  }
}

// Run backup
backupNestedProfileData()
  .then(() => {
    console.log('\n🎉 Backup script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Backup script failed:', error);
    process.exit(1);
  });
