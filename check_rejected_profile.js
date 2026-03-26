#!/usr/bin/env node

/**
 * CHECK REJECTED PROFILE STATE
 * 
 * Validates the Firestore state of a rejected profile to ensure
 * rejection was properly applied.
 * 
 * USAGE:
 *   node check_rejected_profile.js <userId>
 * 
 * EXAMPLE:
 *   node check_rejected_profile.js yOREuYnKEBhX5KiWGtPQ6cj3Jn72
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

async function checkRejectedProfile(userId) {
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

    console.log(`\n📋 DATING PROFILE STATE:`);
    console.log(`   verificationStatus: ${dating.verificationStatus || 'NOT SET'}`);
    console.log(`   rejectionReason: ${dating.rejectionReason || 'NOT SET'}`);
    console.log(`   rejectedAt: ${dating.rejectedAt?.toDate?.() || dating.rejectedAt || 'NOT SET'}`);
    console.log(`   profileCompleted: ${dating.profileCompleted}`);
    console.log(`   isActive: ${dating.isActive}`);
    console.log(`   optIn: ${dating.optIn}`);

    console.log(`\n📸 PROFILE DATA:`);
    console.log(`   Has photos (root): ${userData.photos ? userData.photos.length : 0}`);
    console.log(`   Has audioPrompts (root): ${userData.audioPrompts ? userData.audioPrompts.length : 0}`);
    console.log(`   Has profileUrl (root): ${userData.profileUrl ? '✓' : '✗'}`);
    console.log(`   Has dating.profile (nested): ${dating.profile ? '✓' : '✗'}`);
    console.log(`   Has dating.audioPrompts: ${dating.audioPrompts ? dating.audioPrompts.length : 0}`);
    console.log(`   Has dating.reviewPack: ${dating.reviewPack ? '✓' : '✗'}`);

    console.log(`\n🔎 REJECTION VALIDATION:`);
    
    const issues = [];
    
    if (!dating.rejectionReason && !dating.rejectedAt) {
      issues.push('❌ Profile does NOT appear to be rejected (no rejectionReason or rejectedAt)');
    } else {
      console.log(`✅ Profile IS rejected`);
      console.log(`   Reason: ${dating.rejectionReason}`);
      console.log(`   Timestamp: ${dating.rejectedAt?.toDate?.() || dating.rejectedAt}`);
    }

    if (dating.profileCompleted !== false) {
      issues.push(`❌ profileCompleted is NOT false (current: ${dating.profileCompleted})`);
    } else {
      console.log(`✅ profileCompleted is correctly set to false`);
    }

    if (userData.photos && userData.photos.length > 0) {
      issues.push(`❌ Root-level photos still exist (${userData.photos.length} photos)`);
    } else {
      console.log(`✅ Root-level photos cleared`);
    }

    if (dating.reviewPack) {
      issues.push(`❌ dating.reviewPack still exists`);
    } else {
      console.log(`✅ dating.reviewPack deleted`);
    }

    if (dating.profile) {
      issues.push(`❌ dating.profile still exists`);
    } else {
      console.log(`✅ dating.profile deleted`);
    }

    if (issues.length > 0) {
      console.log(`\n⚠️  ISSUES FOUND:`);
      issues.forEach(issue => console.log(`   ${issue}`));
    } else {
      console.log(`\n✅ ALL VALIDATION CHECKS PASSED`);
    }

    console.log('\n');

  } catch (error) {
    console.error(`\n❌ Error: ${error.message}\n`);
    process.exit(1);
  }
}

// Get userId from command line argument
const userId = process.argv[2];

if (!userId) {
  console.error(`
Usage: node check_rejected_profile.js <userId>

Arguments:
  <userId>  User ID (e.g., yOREuYnKEBhX5KiWGtPQ6cj3Jn72)

Example:
  node check_rejected_profile.js yOREuYnKEBhX5KiWGtPQ6cj3Jn72
  `);
  process.exit(1);
}

checkRejectedProfile(userId);
