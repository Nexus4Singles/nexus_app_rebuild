/**
 * Verify Profile Data Consolidation
 * 
 * This script verifies the cleanup was successful and data integrity is maintained.
 * 
 * Run with: node scripts/verify_profile_cleanup.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('../serviceAccount.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function verifyCleanup() {
  console.log('🔍 Verifying profile data consolidation...\n');

  const usersRef = db.collection('users');
  
  let totalUsers = 0;
  let usersWithNestedData = 0;
  let usersWithRootData = 0;
  let usersWithMissingFields = [];

  try {
    const snapshot = await usersRef.get();
    console.log(`📊 Checking ${snapshot.size} user documents\n`);

    for (const doc of snapshot.docs) {
      totalUsers++;
      const uid = doc.id;
      const data = doc.data();

      // Check for remaining nested data (should be 0 after cleanup)
      const hasNestedDating = data.dating?.profile;
      const hasNestedNexus2 = data.nexus2?.profile;
      const hasCountryInContactInfo = data.dating?.contactInfo?.countryOfResidence;

      if (hasNestedDating || hasNestedNexus2 || hasCountryInContactInfo) {
        usersWithNestedData++;
        console.log(`  ⚠️  User ${uid} still has nested data:`);
        if (hasNestedDating) console.log(`      - dating.profile exists`);
        if (hasNestedNexus2) console.log(`      - nexus2.profile exists`);
        if (hasCountryInContactInfo) console.log(`      - contactInfo.countryOfResidence exists`);
      }

      // Check for root-level fields (should have data)
      const hasRootFields = data.age || data.country || data.profession || data.educationLevel;
      if (hasRootFields) {
        usersWithRootData++;
      }

      // Check for users with potentially missing critical data
      const hasCriticalFields = data.name || data.username || data.age;
      if (!hasCriticalFields) {
        usersWithMissingFields.push(uid);
      }

      if (totalUsers % 100 === 0) {
        console.log(`  Verified ${totalUsers} users...`);
      }
    }

    console.log('\n📊 Verification Results:');
    console.log(`   Total users: ${totalUsers}`);
    console.log(`   Users with nested data (should be 0): ${usersWithNestedData}`);
    console.log(`   Users with root-level data: ${usersWithRootData}`);
    console.log(`   Users with missing critical fields: ${usersWithMissingFields.length}`);

    if (usersWithNestedData === 0) {
      console.log('\n✅ SUCCESS: All nested data cleaned up!');
    } else {
      console.log('\n⚠️  WARNING: Some users still have nested data');
      console.log('   You may need to run the cleanup script again.');
    }

    if (usersWithMissingFields.length > 0) {
      console.log('\n⚠️  Users with missing critical fields:');
      usersWithMissingFields.slice(0, 10).forEach(uid => {
        console.log(`   - ${uid}`);
      });
      if (usersWithMissingFields.length > 10) {
        console.log(`   ... and ${usersWithMissingFields.length - 10} more`);
      }
    }

  } catch (error) {
    console.error('❌ Fatal error during verification:', error);
    process.exit(1);
  }
}

// Run verification
verifyCleanup()
  .then(() => {
    console.log('\n🎉 Verification complete');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Verification failed:', error);
    process.exit(1);
  });
