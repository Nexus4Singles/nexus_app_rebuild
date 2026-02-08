#!/usr/bin/env node

/**
 * Diagnostic script to check verification status of V1 users
 * Helps identify why verified users still show as unverified
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '../serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();

async function diagnoseVerificationStatus() {
  console.log('🔍 Diagnosing verification status...\n');

  try {
    // Get some V1 users that should have been verified
    const v1UsersSnap = await db
      .collection('users')
      .where('schemaVersion', '<', 2)
      .limit(10)
      .get();

    console.log(`📊 Checking ${v1UsersSnap.size} V1 users:\n`);

    let verifiedCount = 0;
    let unverifiedCount = 0;
    let dataStructureIssues = [];

    v1UsersSnap.forEach(doc => {
      const data = doc.data();
      const username = data.username || data.name || 'Unknown';
      
      // Check nested dating object
      const dating = data.dating;
      const verificationStatus = dating?.verificationStatus;
      
      // Check if user is eligible
      const hasPhotos = Array.isArray(data.photos) && data.photos.length > 0;
      const regProgress = (data.registration_progress ?? '').toString().toLowerCase().trim();
      const hasCompatibility = data.compatibility_setted === true;
      const isEligible = hasPhotos && regProgress === 'completed' && hasCompatibility;

      console.log(`${doc.id} (${username}):`);
      console.log(`  ├─ Eligible: ${isEligible ? '✅ YES' : '❌ NO'}`);
      console.log(`  ├─ Photos: ${hasPhotos ? '✅' : '❌'} (${data.photos?.length || 0})`);
      console.log(`  ├─ Registration: ${regProgress}`);
      console.log(`  ├─ Quiz: ${hasCompatibility ? '✅' : '❌'}`);
      console.log(`  └─ Verification Status: "${verificationStatus}"`);

      if (isEligible) {
        if (verificationStatus === 'verified') {
          verifiedCount++;
          console.log(`     ✅ CORRECT - Eligible user is verified\n`);
        } else {
          unverifiedCount++;
          console.log(`     ⚠️  PROBLEM - Eligible user should be verified but is: "${verificationStatus}"\n`);
        }
      }

      // Check data structure issues
      if (!dating) {
        dataStructureIssues.push({
          uid: doc.id,
          username,
          issue: 'No dating object exists'
        });
      }
    });

    console.log('📈 Summary:');
    console.log(`   Eligible users that ARE verified: ${verifiedCount}`);
    console.log(`   Eligible users that are NOT verified: ${unverifiedCount}`);
    
    if (dataStructureIssues.length > 0) {
      console.log(`\n⚠️  Data Structure Issues (${dataStructureIssues.length}):`);
      dataStructureIssues.forEach(issue => {
        console.log(`   - ${issue.uid} (${issue.username}): ${issue.issue}`);
      });
    }

    // Get a sample of the exact query used in the app to see what it returns
    console.log('\n🔍 Checking what search results would return...\n');
    
    const searchResultsSnap = await db
      .collection('users')
      .where('dating.verificationStatus', '==', 'verified')
      .limit(5)
      .get();

    console.log(`Verified profiles in search (sample): ${searchResultsSnap.size}\n`);

  } catch (error) {
    console.error('❌ Error during diagnosis:', error);
    process.exit(1);
  }
}

// Run the diagnostic
diagnoseVerificationStatus()
  .then(() => {
    console.log('✨ Diagnosis complete!');
    process.exit(0);
  })
  .catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
