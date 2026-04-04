#!/usr/bin/env node

/**
 * FIX REJECTED PROFILE - CLEANUP PROFILE DATA
 * 
 * Properly cleans up a rejected profile that still has data lingering.
 * Use this when a profile is marked rejected but the data wasn't deleted.
 * 
 * USAGE:
 *   node fix_rejected_profile.js <userId>
 * 
 * EXAMPLE:
 *   node fix_rejected_profile.js yOREuYnKEBhX5KiWGtPQ6cj3Jn72
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

async function fixRejectedProfile(userId) {
  try {
    const db = admin.firestore();
    
    console.log(`\n🔍 Looking up user: ${userId}`);
    
    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      console.log(`❌ User document not found\n`);
      process.exit(1);
    }

    const userData = userDoc.data();
    const dating = userData.dating || {};

    console.log(`✅ Found user: ${userId}`);
    console.log(`   Email: ${userData.email || 'N/A'}`);
    console.log(`   Username: ${userData.username || userData.name || 'N/A'}`);

    // Verify it's actually rejected
    if (!dating.rejectedAt) {
      console.log(`\n⚠️  Profile does not appear to be rejected (no rejectedAt timestamp)`);
      console.log(`   verificationStatus: ${dating.verificationStatus || 'NOT SET'}`);
      console.log(`   Aborting cleanup.\n`);
      process.exit(0);
    }

    console.log(`\n📋 Current state:`);
    console.log(`   verificationStatus: ${dating.verificationStatus}`);
    console.log(`   rejectionReason: ${dating.rejectionReason}`);
    console.log(`   rejectedAt: ${dating.rejectedAt?.toDate?.() || dating.rejectedAt}`);
    console.log(`   profileCompleted: ${dating.profileCompleted}`);

    console.log(`\n🔄 Performing cleanup...`);

    const updateData = {
      // Clear all profile data (same as when rejection happens)
      'photos': admin.firestore.FieldValue.delete(),
      'audioPrompts': admin.firestore.FieldValue.delete(),
      'audioDurations': admin.firestore.FieldValue.delete(),
      'profileUrl': admin.firestore.FieldValue.delete(),
      
      // Delete dating nested structures
      'dating.reviewPack': admin.firestore.FieldValue.delete(),
      'dating.profile': admin.firestore.FieldValue.delete(),
      'dating.audioPrompts': admin.firestore.FieldValue.delete(),
      
      // Reset completion flags
      'dating.profileCompleted': false,
      'dating.isActive': false,
      'dating.optIn': false,
    };

    await db.collection('users').doc(userId).update(updateData);

    console.log(`✅ Cleanup completed!\n`);

    // Verify the fix
    const updatedDoc = await db.collection('users').doc(userId).get();
    const updatedData = updatedDoc.data();
    const updatedDating = updatedData.dating || {};

    console.log(`📋 Updated state:`);
    console.log(`   profileCompleted: ${updatedDating.profileCompleted}`);
    console.log(`   isActive: ${updatedDating.isActive}`);
    console.log(`   optIn: ${updatedDating.optIn}`);
    console.log(`   Has photos: ${updatedData.photos ? updatedData.photos.length : 0}`);
    console.log(`   Has audioPrompts: ${updatedData.audioPrompts ? updatedData.audioPrompts.length : 0}`);
    console.log(`   Has dating.profile: ${updatedDating.profile ? '✓' : '✗'}`);
    console.log(`   Has dating.reviewPack: ${updatedDating.reviewPack ? '✓' : '✗'}`);

    console.log(`\n✅ Profile is now properly rejected and hidden!\n`);

  } catch (error) {
    console.error(`\n❌ Error: ${error.message}\n`);
    process.exit(1);
  }
}

// Get userId from command line argument
const userId = process.argv[2];

if (!userId) {
  console.error(`
Usage: node fix_rejected_profile.js <userId>

Arguments:
  <userId>  User ID (e.g., yOREuYnKEBhX5KiWGtPQ6cj3Jn72)

Example:
  node fix_rejected_profile.js yOREuYnKEBhX5KiWGtPQ6cj3Jn72
  `);
  process.exit(1);
}

fixRejectedProfile(userId);
