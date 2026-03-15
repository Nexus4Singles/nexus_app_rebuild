#!/usr/bin/env node

/**
 * SCRIPT: Set Admin Custom Claim
 * 
 * This script gives a user the admin: true custom claim,
 * allowing them to manually verify other users via the Cloud Function.
 * 
 * USAGE:
 * node scripts/set_admin_claim.js <email>
 * 
 * EXAMPLE:
 * node scripts/set_admin_claim.js aybajalex@gmail.com
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '../serviceAccount.json');
try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'nexus-visibility-app'
  });
} catch (error) {
  console.error('❌ Error loading serviceAccount.json:', error.message);
  process.exit(1);
}

async function setAdminClaim(email) {
  try {
    console.log(`\n${'='.repeat(70)}`);
    console.log(`🔐 Setting Admin Custom Claim`);
    console.log(`${'='.repeat(70)}\n`);
    
    const normalizedEmail = email.trim().toLowerCase();
    console.log(`📧 Email: ${normalizedEmail}`);

    // Get user by email
    console.log('🔍 Looking up user...');
    const userRecord = await admin.auth().getUserByEmail(normalizedEmail);
    const uid = userRecord.uid;
    
    console.log(`✓ Found user: ${uid}`);
    console.log(`   Email: ${userRecord.email}`);
    console.log(`   Display Name: ${userRecord.displayName || '(not set)'}`);

    // Set custom claim
    console.log('\n⚙️  Setting admin: true custom claim...');
    await admin.auth().setCustomUserClaims(uid, { admin: true });
    
    console.log(`✓ Custom claim set successfully`);

    // Verify it was set
    const updated = await admin.auth().getUser(uid);
    console.log(`\n✅ VERIFICATION:`);
    console.log(`   Custom Claims:`, JSON.stringify(updated.customClaims, null, 2));

    console.log(`\n${'='.repeat(70)}`);
    console.log(`✨ SUCCESS! User ${normalizedEmail} is now an admin.`);
    console.log(`${'='.repeat(70)}\n`);
    console.log(`📝 NEXT STEPS:`);
    console.log(`   1. Sign out and back in to refresh the token`);
    console.log(`   2. You can now verify users via the Cloud Function`);
    console.log(`   3. See: scripts/verify_user_via_cf.sh for usage\n`);

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

// Get email from command line
const email = process.argv[2];
if (!email) {
  console.error('\n❌ Usage: node scripts/set_admin_claim.js <email>');
  console.error('   Example: node scripts/set_admin_claim.js aybajalex@gmail.com\n');
  process.exit(1);
}

setAdminClaim(email).then(() => process.exit(0)).catch(err => {
  console.error(err);
  process.exit(1);
});
