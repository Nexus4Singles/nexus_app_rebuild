#!/usr/bin/env node

/**
 * FIX REJECTED PROFILE FOR RECREATION
 * 
 * Cleans up rejected profiles so users can recreate them without UX issues.
 * 
 * What this does:
 * - Sets dating.profileCompleted: false (allows re-entry to onboarding)
 * - Preserves dating.verificationStatus: 'rejected' (keeps rejection gate)
 * - Preserves dating.rejectionReason (shows rejection reason in modal)
 * - Deletes old profile data that would interfere with new profile creation
 * 
 * What gets deleted:
 * - Root: photos, audioPrompts, profileUrl
 * - Dating: profile, audioPrompts, reviewPack
 * 
 * USAGE:
 *   node fix_rejected_profile_for_recreation.js <userId|email>
 * 
 * EXAMPLES:
 *   node fix_rejected_profile_for_recreation.js yOREuYnKEBhX5KiWGtPQ6cj3Jn72
 *   node fix_rejected_profile_for_recreation.js user@example.com
 * 
 * REQUIREMENTS:
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

async function fixRejectedProfile(userIdOrEmail) {
  try {
    const db = admin.firestore();
    let userId, userDoc, userData;

    // Determine if input is email or userId
    const isEmail = userIdOrEmail.includes('@');

    if (isEmail) {
      console.log(`\n🔍 Looking up user by email: ${userIdOrEmail}`);
      const usersSnapshot = await db
        .collection('users')
        .where('email', '==', userIdOrEmail)
        .limit(1)
        .get();

      if (usersSnapshot.empty) {
        console.log(`❌ No user found with email: ${userIdOrEmail}\n`);
        process.exit(1);
      }

      userDoc = usersSnapshot.docs[0];
      userId = userDoc.id;
      userData = userDoc.data();
    } else {
      console.log(`\n🔍 Looking up user by ID: ${userIdOrEmail}`);
      userDoc = await db.collection('users').doc(userIdOrEmail).get();

      if (!userDoc.exists) {
        console.log(`❌ No user found with ID: ${userIdOrEmail}\n`);
        process.exit(1);
      }

      userId = userIdOrEmail;
      userData = userDoc.data();
    }

    console.log(`✅ Found user: ${userId}`);
    console.log(`   Email: ${userData.email}`);
    console.log(`   Username: ${userData.username || userData.name || 'N/A'}`);

    // Check rejection status
    const dating = userData.dating || {};
    const verificationStatus = dating.verificationStatus;
    const rejectionReason = dating.rejectionReason;

    console.log(`\n📋 Current Dating Profile Status:`);
    console.log(`   verificationStatus: ${verificationStatus}`);
    console.log(`   rejectionReason: ${rejectionReason || 'NOT SET'}`);
    console.log(`   profileCompleted: ${dating.profileCompleted}`);
    console.log(`   rejectedAt: ${dating.rejectedAt?.toDate?.() || dating.rejectedAt || 'NOT SET'}`);

    // Validate this is actually a rejected profile
    if (verificationStatus !== 'rejected') {
      console.log(
        `\n⚠️  WARNING: User's verificationStatus is "${verificationStatus}", not "rejected"`
      );
      console.log(`   This user may not be rejected. Aborting.\n`);
      process.exit(0);
    }

    // Build cleanup updates
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

    console.log(`\n🧹 Cleaning up profile data...`);
    console.log(`   ✓ Setting profileCompleted: false`);
    console.log(`   ✓ Deleting root.photos`);
    console.log(`   ✓ Deleting root.audioPrompts`);
    console.log(`   ✓ Deleting root.profileUrl`);
    console.log(`   ✓ Deleting dating.profile`);
    console.log(`   ✓ Deleting dating.audioPrompts`);
    console.log(`   ✓ Deleting dating.reviewPack`);

    // Preserving rejection metadata:
    console.log(`\n🔐 Preserving rejection metadata:`);
    console.log(`   ✓ dating.verificationStatus: ${verificationStatus}`);
    console.log(`   ✓ dating.rejectionReason: "${rejectionReason}"`);
    console.log(`   ✓ dating.rejectedAt`);
    console.log(`   ✓ dating.verifiedBy`);
    console.log(`   ✓ dating.reviewedBy`);
    console.log(`   ✓ dating.reviewedAt`);

    // Apply updates
    await db.collection('users').doc(userId).update(updates);

    console.log(`\n✅ Profile successfully fixed!\n`);
    console.log(`✨ User can now:
   1. See rejection modal with reason when accessing dating features
   2. Click "Create New Profile" button
   3. Go through onboarding flow again (fresh start)
   4. Submit new profile for admin review\n`);

  } catch (error) {
    console.error(`\n❌ Error: ${error.message}\n`);
    process.exit(1);
  }
}

// Get user ID/email from command line argument
const userIdOrEmail = process.argv[2];

if (!userIdOrEmail) {
  console.error(`
Usage: node fix_rejected_profile_for_recreation.js <userId|email>

Arguments:
  <userId|email>  User ID or email address

Examples:
  node fix_rejected_profile_for_recreation.js yOREuYnKEBhX5KiWGtPQ6cj3Jn72
  node fix_rejected_profile_for_recreation.js user@example.com
  `);
  process.exit(1);
}

fixRejectedProfile(userIdOrEmail);
