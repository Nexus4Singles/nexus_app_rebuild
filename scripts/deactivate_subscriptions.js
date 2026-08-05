/*
 Script: deactivate_subscriptions.js
 Usage: node scripts/deactivate_subscriptions.js

 This script uses the Firebase Admin SDK to find users by email,
 then clears their active subscription fields in Firestore so you can
 re-test subscription flows.

 IMPORTANT: Ensure `serviceAccount.json` exists at the repo root and
 the service account has Firestore and Auth privileges.
*/

const admin = require('firebase-admin');
const fs = require('fs');

const path = require('path');
// Resolve service account at repo root (one level above scripts/)
const SERVICE_ACCOUNT_PATH = path.resolve(__dirname, '..', 'serviceAccount.json');
const TARGET_EMAILS = ['ayomidebaj@gmail.com', 'contact@nexus4singles.com'];

if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error(`serviceAccount.json not found at ${SERVICE_ACCOUNT_PATH}. Place it and retry.`);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(SERVICE_ACCOUNT_PATH)),
});

const db = admin.firestore();

async function deactivateByEmail(email) {
  try {
    console.log(`Looking up user for email: ${email}`);
    const userRecord = await admin.auth().getUserByEmail(email);
    const uid = userRecord.uid;
    console.log(`Found uid=${uid} for ${email}. Updating Firestore...`);

    const userRef = db.collection('users').doc(uid);
    await userRef.update({
      'subscription.isActive': false,
      'subscription.autoRenew': false,
      'subscription.expiryDate': null,
      'onPremium': false,
      'entitledUser': false,
      'subExpDate': null,
      'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Deactivated subscription for ${email} (uid=${uid})`);
  } catch (err) {
    console.error(`⚠️ Failed to deactivate for ${email}:`, err.message || err);
  }
}

(async () => {
  for (const email of TARGET_EMAILS) {
    await deactivateByEmail(email);
  }
  console.log('Done.');
  process.exit(0);
})();
