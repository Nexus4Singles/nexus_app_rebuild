#!/usr/bin/env node

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin using the service account
const serviceAccountPath = path.join(__dirname, 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function findMatches(rcId) {
  console.log(`Searching for RevenueCat customer id: ${rcId}`);

  // 1) Direct doc id
  const direct = await db.collection('users').doc(rcId).get();
  if (direct.exists) {
    console.log(`Found direct user doc with id: ${direct.id}`);
    console.log(direct.data());
    return [{ id: direct.id, data: direct.data() }];
  }

  // 2) revenueCat.customerId
  const byRc = await db.collection('users').where('revenueCat.customerId', '==', rcId).limit(10).get();
  if (!byRc.empty) {
    console.log(`Found ${byRc.size} user(s) with revenueCat.customerId == ${rcId}`);
    return byRc.docs.map(d => ({ id: d.id, data: d.data() }));
  }

  // 3) subscription.revenueCatCustomerId
  const bySub = await db.collection('users').where('subscription.revenueCatCustomerId', '==', rcId).limit(10).get();
  if (!bySub.empty) {
    console.log(`Found ${bySub.size} user(s) with subscription.revenueCatCustomerId == ${rcId}`);
    return bySub.docs.map(d => ({ id: d.id, data: d.data() }));
  }

  // 4) Fallback: search by email derived from RevenueCat event if available - not implemented here
  console.log('No direct matches found. Check the `revenuecat_orphaned_events` collection for details.');
  return [];
}

async function claim(rcId, targetUid) {
  // Assign revenueCat.customerId to target user and mark orphan as handled
  const matches = await findMatches(rcId);
  if (matches.length > 0) {
    console.log('Matches exist; no claiming necessary.');
    return;
  }

  if (!targetUid) {
    console.error('No matches found and no target UID provided to claim. Exiting.');
    process.exit(1);
  }

  const targetRef = db.collection('users').doc(targetUid);
  const snap = await targetRef.get();
  if (!snap.exists) {
    console.error(`Target user ${targetUid} not found.`);
    process.exit(1);
  }

  await targetRef.set({ revenueCat: { customerId: rcId, claimedAt: admin.firestore.FieldValue.serverTimestamp() } }, { merge: true });
  console.log(`Assigned RevenueCat customerId ${rcId} to user ${targetUid}`);
}

(async () => {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    console.error('Usage: node reconcile_revenuecat.js <revenuecat_customer_id> [claim_user_uid]');
    process.exit(1);
  }

  const rcId = args[0];
  const claimUid = args[1];

  if (claimUid) {
    await claim(rcId, claimUid);
  } else {
    const results = await findMatches(rcId);
    if (results.length === 0) {
      console.log('No matches found. Consider running:');
      console.log(`  node reconcile_revenuecat.js ${rcId} <targetFirebaseUid>`);
    } else {
      console.log('Done.');
    }
  }
  process.exit(0);
})();
