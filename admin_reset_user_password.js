#!/usr/bin/env node
/**
 * Admin Password Reset Tool
 *
 * Two ways to help a user regain access without email:
 *
 * OPTION 1 — Generate a reset link (share it with the user directly via SMS/WhatsApp/etc.):
 *   node admin_reset_user_password.js link <email>
 *
 * OPTION 2 — Set a temporary password the user can change after logging in:
 *   node admin_reset_user_password.js setpass <email> <newTemporaryPassword>
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const [, , mode, email, tempPassword] = process.argv;

if (!mode || !email) {
  console.log(`
Usage:
  Generate a shareable reset link:
    node admin_reset_user_password.js link <email>

  Set a temporary password:
    node admin_reset_user_password.js setpass <email> <newTemporaryPassword>
`);
  process.exit(1);
}

async function generateResetLink(email) {
  console.log(`\n🔍 Looking up Firebase Auth user: ${email}`);

  try {
    const userRecord = await admin.auth().getUserByEmail(email);
    console.log(`✅ Found user — UID: ${userRecord.uid}`);

    const link = await admin.auth().generatePasswordResetLink(email);

    console.log(`\n✅ Password reset link generated successfully!`);
    console.log(`\n📋 Share this link with the user via SMS, WhatsApp, or any other channel:\n`);
    console.log(`   ${link}`);
    console.log(`\n⚠️  This link expires after 1 hour and can only be used once.`);
    console.log(`   Instruct the user to open it in the same browser/device they normally use.\n`);
  } catch (err) {
    if (err.code === 'auth/user-not-found') {
      console.error(`\n❌ No Firebase Auth account found for: ${email}`);
      console.error(`   The user may have signed up with a different email or via social login.\n`);
    } else {
      console.error(`\n❌ Error: ${err.message}\n`);
    }
    process.exit(1);
  }
}

async function setTemporaryPassword(email, password) {
  if (!password || password.length < 8) {
    console.error('\n❌ Temporary password must be at least 8 characters.\n');
    process.exit(1);
  }

  console.log(`\n🔍 Looking up Firebase Auth user: ${email}`);

  try {
    const userRecord = await admin.auth().getUserByEmail(email);
    console.log(`✅ Found user — UID: ${userRecord.uid}`);

    await admin.auth().updateUser(userRecord.uid, { password });

    console.log(`\n✅ Password updated successfully!`);
    console.log(`\n📋 Tell the user:`);
    console.log(`   Email:    ${email}`);
    console.log(`   Temp password: ${password}`);
    console.log(`\n⚠️  Ask them to change their password immediately after logging in.\n`);
  } catch (err) {
    if (err.code === 'auth/user-not-found') {
      console.error(`\n❌ No Firebase Auth account found for: ${email}`);
      console.error(`   The user may have signed up with a different email or via social login.\n`);
    } else {
      console.error(`\n❌ Error: ${err.message}\n`);
    }
    process.exit(1);
  }
}

(async () => {
  if (mode === 'link') {
    await generateResetLink(email);
  } else if (mode === 'setpass') {
    await setTemporaryPassword(email, tempPassword);
  } else {
    console.error(`\n❌ Unknown mode "${mode}". Use "link" or "setpass".\n`);
    process.exit(1);
  }

  process.exit(0);
})();
