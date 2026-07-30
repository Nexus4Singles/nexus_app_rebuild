#!/usr/bin/env node

/**
 * Remove UK dummy/test profiles created for prelaunch validation.
 *
 * Usage:
 *   node scripts/cleanup_uk_dummy_profiles.js
 *   node scripts/cleanup_uk_dummy_profiles.js --dry-run
 */

const path = require('path');
const admin = require('firebase-admin');

const serviceAccountPath = path.join(__dirname, '..', 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();
const dryRun = process.argv.includes('--dry-run');

async function cleanupDummyProfiles() {
  console.log(dryRun ? '🧪 Dry run: scanning for dummy profiles...' : '🧹 Cleaning up dummy profiles...');

  const snapshot = await db
    .collection('users')
    .where('isDummyProfile', '==', true)
    .get();

  console.log(`Found ${snapshot.size} dummy profile documents`);

  if (snapshot.size === 0) {
    return;
  }

  const batch = db.batch();
  let deleteCount = 0;

  for (const doc of snapshot.docs) {
    if (dryRun) {
      console.log(`Would delete ${doc.id} (${doc.data().name || 'unnamed'})`);
      continue;
    }

    batch.delete(doc.ref);
    deleteCount += 1;
  }

  if (!dryRun) {
    await batch.commit();
    console.log(`Deleted ${deleteCount} dummy profiles`);
  }

  // Set UK market back to prelaunch as a safety default.
  if (!dryRun) {
    await db.collection('markets').doc('uk').set(
      {
        phase: 'prelaunch',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    console.log('Updated markets/uk -> phase: prelaunch');
  }
}

cleanupDummyProfiles()
  .catch((error) => {
    console.error('❌ Cleanup failed:', error);
    process.exit(1);
  })
  .finally(() => {
    if (dryRun) {
      console.log('Dry run complete');
    }
    process.exit(0);
  });
