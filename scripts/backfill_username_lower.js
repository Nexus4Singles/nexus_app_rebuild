#!/usr/bin/env node
/**
 * One-time migration script: backfill `username_lower` for all existing users.
 *
 * This ensures legacy users (created before the username_lower field was added)
 * can log in with case-insensitive username matching.
 *
 * Usage:
 *   node scripts/backfill_username_lower.js
 *
 * Requirements:
 *   - serviceAccount.json at the project root (or set GOOGLE_APPLICATION_CREDENTIALS)
 *   - firebase-admin installed: npm install firebase-admin
 *
 * Safe to re-run — it only touches docs that have a username but no username_lower.
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialise with local service account
const serviceAccountPath = path.resolve(__dirname, '..', 'serviceAccount.json');
admin.initializeApp({
  credential: admin.credential.cert(require(serviceAccountPath)),
});

const db = admin.firestore();

async function backfillUsernameLower() {
  const usersRef = db.collection('users');
  const snapshot = await usersRef.get();

  let updated = 0;
  let skipped = 0;
  let noUsername = 0;
  let alreadyHas = 0;

  // Firestore batched writes are limited to 500 operations per batch
  const BATCH_LIMIT = 500;
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const username = data.username;

    if (!username || typeof username !== 'string' || username.trim() === '') {
      noUsername++;
      continue;
    }

    if (data.username_lower) {
      alreadyHas++;
      continue;
    }

    // Normalise: lowercase + collapse multiple spaces into single space
    const normalised = username.trim().replace(/\s+/g, ' ').toLowerCase();

    batch.update(doc.ref, { username_lower: normalised });
    batchCount++;
    updated++;

    if (batchCount >= BATCH_LIMIT) {
      await batch.commit();
      console.log(`  … committed batch of ${batchCount}`);
      batch = db.batch();
      batchCount = 0;
    }
  }

  // Commit remaining
  if (batchCount > 0) {
    await batch.commit();
  }

  console.log('\n=== Backfill complete ===');
  console.log(`Total docs scanned : ${snapshot.docs.length}`);
  console.log(`Updated (added)    : ${updated}`);
  console.log(`Already had field  : ${alreadyHas}`);
  console.log(`No username set    : ${noUsername}`);
  console.log(`Skipped (other)    : ${skipped}`);
}

backfillUsernameLower()
  .then(() => {
    console.log('\nDone.');
    process.exit(0);
  })
  .catch((err) => {
    console.error('Migration failed:', err);
    process.exit(1);
  });
