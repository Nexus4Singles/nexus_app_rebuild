#!/usr/bin/env node
/**
 * Set or unset Firebase Auth custom claim { admin: true } for a user.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=/abs/path/to/serviceAccount.json \
 *     node functions/scripts/set_admin_claim.js --email "admin@example.com"
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=/abs/path/to/serviceAccount.json \
 *     node functions/scripts/set_admin_claim.js --uid "<UID>"
 *
 *   # Unset:
 *   GOOGLE_APPLICATION_CREDENTIALS=/abs/path/to/serviceAccount.json \
 *     node functions/scripts/set_admin_claim.js --uid "<UID>" --unset
 */

const admin = require("firebase-admin");

function argValue(flag) {
  const i = process.argv.indexOf(flag);
  if (i === -1) return null;
  const v = process.argv[i + 1];
  if (!v || v.startsWith("--")) return null;
  return v;
}

function hasFlag(flag) {
  return process.argv.includes(flag);
}

async function main() {
  const uid = argValue("--uid");
  const email = argValue("--email");
  const unset = hasFlag("--unset");

  if (!uid && !email) {
    console.error("ERROR: Provide --uid or --email");
    process.exit(2);
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });

  let user;
  if (uid) {
    user = await admin.auth().getUser(uid);
  } else {
    user = await admin.auth().getUserByEmail(email);
  }

  const targetUid = user.uid;

  const claims = user.customClaims || {};
  if (unset) {
    // Remove admin claim
    if (claims.admin === undefined) {
      console.log(`No admin claim present for uid=${targetUid}. Nothing to do.`);
      return;
    }
    const { admin: _removed, ...rest } = claims;
    await admin.auth().setCustomUserClaims(targetUid, rest);
    console.log(`Unset admin claim for uid=${targetUid}`);
  } else {
    if (claims.admin === true) {
      console.log(`Admin claim already set for uid=${targetUid}. Nothing to do.`);
      return;
    }
    await admin.auth().setCustomUserClaims(targetUid, { ...claims, admin: true });
    console.log(`Set admin claim for uid=${targetUid}`);
  }

  console.log("NOTE: The user must sign out/in (or refresh ID token) for the claim to propagate to the client.");
}

main().catch((e) => {
  console.error("FAILED:", e && e.stack ? e.stack : e);
  process.exit(1);
});
