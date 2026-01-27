/*
Usage:
  node scripts/set_admin_claim.js --email user@example.com --admin true
  node scripts/set_admin_claim.js --uid ABC123 --admin false

Requires serviceAccount.json in project root.
*/

const admin = require('firebase-admin');
const yargs = require('yargs/yargs');
const { hideBin } = require('yargs/helpers');

const argv = yargs(hideBin(process.argv))
  .option('email', { type: 'string', describe: 'User email' })
  .option('uid', { type: 'string', describe: 'User UID' })
  .option('admin', { type: 'boolean', demandOption: true, describe: 'Set admin true/false' })
  .strict()
  .help()
  .argv;

if (!argv.email && !argv.uid) {
  console.error('Provide --email or --uid');
  process.exit(1);
}

const serviceAccount = require('../serviceAccount.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

(async () => {
  try {
    let uid = argv.uid;

    if (!uid) {
      const user = await admin.auth().getUserByEmail(argv.email);
      uid = user.uid;
    }

    const current = await admin.auth().getUser(uid);
    const claims = { ...(current.customClaims || {}) };
    claims.admin = !!argv.admin;

    await admin.auth().setCustomUserClaims(uid, claims);

    console.log(`✅ Updated admin claim for ${uid} -> ${claims.admin}`);

    // Force token refresh by updating a metadata field so client picks up new claims
    await admin.auth().updateUser(uid, { disabled: current.disabled });

    process.exit(0);
  } catch (e) {
    console.error('❌ Error setting admin claim:', e);
    process.exit(1);
  }
})();
/**
 * Set Admin Custom Claim
 * 
 * This script sets the 'admin' custom claim on a Firebase Auth user.
 * This is required for the app to recognize the user as an admin.
 * 
 * Usage: node scripts/set_admin_claim.js <email_or_uid>
 * Example: node scripts/set_admin_claim.js nexus4singles@gmail.com
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('../serviceAccount.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const auth = admin.auth();
const db = admin.firestore();

async function setAdminClaim(emailOrUid) {
  if (!emailOrUid) {
    console.error('❌ Error: Please provide an email or UID');
    console.log('\nUsage: node scripts/set_admin_claim.js <email_or_uid>');
    console.log('Example: node scripts/set_admin_claim.js nexus4singles@gmail.com\n');
    process.exit(1);
  }

  try {
    console.log(`🔍 Looking up user: ${emailOrUid}\n`);

    let user;
    
    // Try to get user by email first, then by UID
    if (emailOrUid.includes('@')) {
      user = await auth.getUserByEmail(emailOrUid);
    } else {
      user = await auth.getUser(emailOrUid);
    }

    console.log(`✅ Found user:`);
    console.log(`   UID: ${user.uid}`);
    console.log(`   Email: ${user.email || 'N/A'}`);
    console.log(`   Display Name: ${user.displayName || 'N/A'}\n`);

    // Check current custom claims
    const currentClaims = user.customClaims || {};
    console.log(`📋 Current custom claims:`, currentClaims);

    if (currentClaims.admin === true) {
      console.log(`\n⚠️  User already has admin claim set to true`);
      console.log(`   No action needed.`);
      return;
    }

    // Set the admin custom claim
    console.log(`\n🔧 Setting admin custom claim...`);
    await auth.setCustomUserClaims(user.uid, {
      ...currentClaims,
      admin: true
    });

    console.log(`✅ Admin claim set successfully!\n`);

    // Also update Firestore document for consistency
    console.log(`🔧 Updating Firestore document...`);
    await db.collection('users').doc(user.uid).update({
      isAdmin: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`✅ Firestore document updated!\n`);

    console.log(`🎉 User ${emailOrUid} is now an admin!`);
    console.log(`\nIMPORTANT: The user must sign out and sign in again for the changes to take effect.`);
    console.log(`This is required for the new custom claims to be included in their ID token.\n`);

  } catch (error) {
    console.error(`❌ Error setting admin claim:`, error.message);
    process.exit(1);
  }
}

// Get email/UID from command line arguments
const emailOrUid = process.argv[2];

// Run the script
setAdminClaim(emailOrUid)
  .then(() => {
    console.log(`✅ Script completed successfully`);
    process.exit(0);
  })
  .catch((error) => {
    console.error(`❌ Script failed:`, error);
    process.exit(1);
  });
