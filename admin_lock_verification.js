#!/usr/bin/env node

/**
 * Admin script to set and lock verification status for a user
 * This allows admin to permanently set verification without auto-reset
 * 
 * Usage:
 *   node admin_lock_verification.js <email> <verify|unverify>
 * 
 * Examples:
 *   node admin_lock_verification.js nexus4singles@gmail.com verify
 *   node admin_lock_verification.js nexus4singles@gmail.com unverify
 */

const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

async function setVerification(email, shouldVerify) {
  try {
    console.log(`🔍 Looking up user: ${email}`);
    
    // Get user by email
    let uid;
    try {
      const userRecord = await auth.getUserByEmail(email);
      uid = userRecord.uid;
      console.log(`✅ Found user UID: ${uid}`);
    } catch (err) {
      console.error(`❌ User not found: ${email}`);
      process.exit(1);
    }

    // Get current user document
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      console.error(`❌ User document not found in Firestore: ${uid}`);
      process.exit(1);
    }

    const userData = userDoc.data();
    const dating = userData.dating || {};
    const currentStatus = dating.verificationStatus || 'unverified';
    const currentLock = dating.verificationLockedByAdmin || false;
    
    console.log(`📋 Current verification status: ${currentStatus}`);
    console.log(`🔐 Current lock status: ${currentLock ? 'LOCKED' : 'UNLOCKED'}`);

    // Update verification status AND lock it
    const updates = {
      'dating.verificationStatus': shouldVerify ? 'verified' : 'unverified',
      'dating.verificationLockedByAdmin': true, // Always lock to prevent auto-reset
      'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    };

    // Add relevant timestamps when verifying
    if (shouldVerify) {
      updates['dating.verifiedAt'] = admin.firestore.FieldValue.serverTimestamp();
      updates['dating.verifiedBy'] = 'admin-cli';
      // Clear rejection data if any
      updates['dating.rejectedAt'] = null;
      updates['dating.rejectedBy'] = null;
      updates['dating.rejectionReason'] = null;
    } else {
      updates['dating.verifiedAt'] = null;
      updates['dating.verifiedBy'] = null;
    }

    await userRef.update(updates);
    
    const action = shouldVerify ? 'verified' : 'unverified';
    console.log(`✅ Account ${action} and LOCKED for ${email}`);
    console.log(`✅ This status is now permanent - it will NOT auto-reset on profile updates`);
    
    // Show summary
    console.log(`\n📊 Final Status:`);
    console.log(`   Verification: ${shouldVerify ? '✅ VERIFIED' : '❌ UNVERIFIED'}`);
    console.log(`   Lock Status: 🔒 LOCKED (permanent)`);

  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  } finally {
    admin.app().delete();
  }
}

// Parse command line arguments
const args = process.argv.slice(2);
if (args.length < 2) {
  console.log(`
Usage: node admin_lock_verification.js <email> <verify|unverify>

Examples:
  node admin_lock_verification.js nexus4singles@gmail.com verify
  node admin_lock_verification.js nexus4singles@gmail.com unverify

This script:
1. Sets the account verification status (verified or unverified)
2. LOCKS it permanently with verificationLockedByAdmin=true
3. Prevents auto-reset to pending when user updates profile
  `);
  process.exit(1);
}

const email = args[0];
const action = args[1].toLowerCase();

if (action !== 'verify' && action !== 'unverify') {
  console.error(`❌ Invalid action: ${action}. Use 'verify' or 'unverify'`);
  process.exit(1);
}

setVerification(email, action === 'verify');
