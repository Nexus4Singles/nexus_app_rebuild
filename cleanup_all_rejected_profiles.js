#!/usr/bin/env node

/**
 * BATCH CLEANUP ALL REJECTED PROFILES
 * 
 * Finds all rejected dating profiles and cleans them up for recreation.
 * This allows users to re-enter onboarding without old data interference.
 * 
 * What this does:
 * - Finds all users with dating.verificationStatus: 'rejected'
 * - Sets dating.profileCompleted: false (allows re-entry)
 * - Deletes old profile data (photos, audio, etc.)
 * - Preserves rejection reason and audit trail
 * - Reports cleanup statistics
 * 
 * USAGE:
 *   node cleanup_all_rejected_profiles.js
 * 
 * REQUIRES:
 *   - serviceAccount.json in project root
 *   - Firebase Admin SDK installed
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function cleanupAllRejectedProfiles() {
  const db = admin.firestore();

  try {
    console.log('\n🔍 Finding all rejected dating profiles...\n');

    // Query all users with rejected status
    const snapshot = await db
      .collection('users')
      .where('dating.verificationStatus', '==', 'rejected')
      .get();

    if (snapshot.empty) {
      console.log('✅ No rejected profiles found. Nothing to clean up.\n');
      process.exit(0);
    }

    const rejectedUsers = [];
    snapshot.forEach((doc) => {
      const data = doc.data();
      rejectedUsers.push({
        userId: doc.id,
        email: data.email,
        username: data.username || data.name || 'N/A',
        rejectionReason: data.dating?.rejectionReason || 'N/A',
        rejectedAt: data.dating?.rejectedAt?.toDate?.() || data.dating?.rejectedAt || 'N/A',
      });
    });

    console.log(`📋 Found ${rejectedUsers.length} rejected profile(s):\n`);
    rejectedUsers.forEach((user, idx) => {
      console.log(`   ${idx + 1}. ${user.email}`);
      console.log(`      Username: ${user.username}`);
      console.log(`      Reason: ${user.rejectionReason}`);
    });

    console.log('\n🧹 Starting cleanup...\n');

    let cleanedCount = 0;
    let errorCount = 0;
    const errors = [];

    for (const user of rejectedUsers) {
      try {
        const userRef = db.collection('users').doc(user.userId);

        const updates = {
          // Set profileCompleted to false so they can re-enter onboarding
          'dating.profileCompleted': false,

          // Delete old profile data
          'photos': admin.firestore.FieldValue.delete(),
          'audioPrompts': admin.firestore.FieldValue.delete(),
          'profileUrl': admin.firestore.FieldValue.delete(),
          'dating.profile': admin.firestore.FieldValue.delete(),
          'dating.audioPrompts': admin.firestore.FieldValue.delete(),
          'dating.reviewPack': admin.firestore.FieldValue.delete(),

          // Add cleanup timestamp
          'dating.profileCleanedUpForRecreationAt': admin.firestore.FieldValue.serverTimestamp(),
        };

        await userRef.update(updates);

        console.log(`✅ ${user.email}`);
        cleanedCount++;
      } catch (error) {
        console.log(`❌ ${user.email} - ${error.message}`);
        errorCount++;
        errors.push(`${user.email}: ${error.message}`);
      }
    }

    console.log('\n' + '='.repeat(60));
    console.log('📊 CLEANUP COMPLETE');
    console.log('='.repeat(60));
    console.log(`   Total rejected profiles: ${rejectedUsers.length}`);
    console.log(`   ✅ Successfully cleaned: ${cleanedCount}`);
    console.log(`   ❌ Failed: ${errorCount}`);

    if (errors.length > 0) {
      console.log('\n⚠️  Errors:');
      errors.forEach((err) => console.log(`   - ${err}`));
    }

    console.log('\n✨ Users can now recreate their profiles through the onboarding flow.\n');
    process.exit(0);
  } catch (error) {
    console.error(`\n❌ Fatal error: ${error.message}\n`);
    process.exit(1);
  }
}

cleanupAllRejectedProfiles();
