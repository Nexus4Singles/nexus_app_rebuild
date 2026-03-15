#!/usr/bin/env node

/**
 * SET ADMIN CUSTOM CLAIM
 * 
 * Adds admin: true custom claim to a Firebase Auth user so they can:
 * - Manually verify other users
 * - Access admin-only Cloud Functions
 * 
 * USAGE:
 *   node set-admin-claim.js <email> [admin_status]
 * 
 * EXAMPLES:
 *   node set-admin-claim.js aybaj@example.com true     # Make user admin
 *   node set-admin-claim.js aybaj@example.com false    # Remove admin access
 * 
 * REQUIREMENTS:
 *   - serviceAccount.json in project root
 *   - Firebase Admin SDK installed
 */

const admin = require('firebase-admin');
const path = require('path');

const email = process.argv[2];
const makeAdmin = (process.argv[3] || 'true').toLowerCase() === 'true';

if (!email) {
  console.error('❌ Usage: node set-admin-claim.js <email> [true/false]');
  console.error('   Default is true (make admin)');
  process.exit(1);
}

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '../serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function setAdminClaim() {
  console.log('\n' + '='.repeat(70));
  console.log(`🔐 SET ADMIN CUSTOM CLAIM`);
  console.log('='.repeat(70) + '\n');

  const normalizedEmail = email.trim().toLowerCase();
  
  try {
    // Step 1: Find user by email
    console.log(`📧 Step 1: Finding Firebase Auth user with email: ${normalizedEmail}`);
    
    let user;
    try {
      user = await admin.auth().getUserByEmail(normalizedEmail);
    } catch (e) {
      console.error(`❌ User not found in Firebase Auth: ${normalizedEmail}`);
      console.error(`   Make sure they've signed up to the app first!\n`);
      process.exit(1);
    }

    console.log(`✅ User found!`);
    console.log(`   UID: ${user.uid}`);
    console.log(`   Email: ${user.email}`);
    console.log(`   Display Name: ${user.displayName || 'N/A'}\n`);

    // Step 2: Check current claims
    console.log(`🔍 Step 2: Checking current custom claims...`);
    const currentClaims = user.customClaims || {};
    const currentAdminStatus = currentClaims.admin === true;
    console.log(`   Current admin status: ${currentAdminStatus}\n`);

    // Step 3: Set custom claims
    if (makeAdmin === currentAdminStatus) {
      console.log(`⏭️  Skipping - user is already ${makeAdmin ? 'admin' : 'not admin'}`);
    } else {
      console.log(`⏳ Step 3: Setting admin custom claim to ${makeAdmin}...`);
      
      const newClaims = { ...currentClaims, admin: makeAdmin };
      await admin.auth().setCustomUserClaims(user.uid, newClaims);
      
      console.log(`✅ Custom claims updated!\n`);
    }

    // Step 4: Display final state
    console.log(`📝 Final custom claims for ${normalizedEmail}:`);
    const updatedUser = await admin.auth().getUser(user.uid);
    const finalClaims = updatedUser.customClaims || {};
    console.log(`   ${JSON.stringify(finalClaims, null, 2)}`);

    console.log('\n' + '='.repeat(70));
    if (makeAdmin) {
      console.log(`✅ SUCCESS! ${normalizedEmail} is now an ADMIN`);
      console.log(`   They can now:`);
      console.log(`   - Manually verify users via Cloud Functions`);
      console.log(`   - Manually verify users via admin CLI scripts`);
      console.log(`   - Edit protected user fields in Firestore`);
    } else {
      console.log(`✅ ADMIN ACCESS REVOKED for ${normalizedEmail}`);
    }
    console.log('='.repeat(70) + '\n');

    process.exit(0);

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.error(error);
    process.exit(1);
  }
}

setAdminClaim();
