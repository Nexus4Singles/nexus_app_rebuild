#!/usr/bin/env node

/**
 * Migration Script: Move root-level profile fields -> dating.profile
 * 
 * SAFE: This only COPIES data, doesn't delete anything
 * Moves: age, gender, name, city, country, phone, photos, etc.
 * Keeps: Both locations for backward compat (don't delete root)
 * 
 * Usage:
 *   node scripts/migrate-profile-to-dating.js --dry-run   (preview changes)
 *   node scripts/migrate-profile-to-dating.js --execute   (do it!)
 */

const admin = require('firebase-admin');

// Profile fields to migrate
const PROFILE_FIELDS = [
  'age', 'gender', 'name', 'username', 'profileUrl', 'city',
  'country', 'countryCode', 'nationality', 'nationalityCode',
  'phoneNumber', 'educationLevel', 'profession', 'churchName',
  'hobbies', 'bestQualotiesOrTraits', 'desiredQualities', 'photos',
  'location',
];

async function migrate() {
  const isDryRun = process.argv.includes('--dry-run');
  const db = admin.firestore();
  
  console.log(`\n${'='.repeat(70)}`);
  console.log('Profile Field Migration: root → dating.profile');
  console.log(`${'='.repeat(70)}`);
  console.log(`Mode: ${isDryRun ? '🚀 DRY RUN (preview)' : '⚡ EXECUTE (real)'}`);
  console.log(`${'='.repeat(70)}\n`);

  try {
    const snapshot = await db.collection('users').get();
    let updated = 0;
    let skipped = 0;
    let errors = 0;
    
    console.log(`Processing ${snapshot.size} users...\n`);
    
    for (const doc of snapshot.docs) {
      const userData = doc.data();
      const updates = {};
      let needsUpdate = false;

      for (const field of PROFILE_FIELDS) {
        const rootValue = userData[field];
        const datingValue = userData?.dating?.profile?.[field];

        // If field exists at root but NOT at dating.profile, copy it
        if (rootValue !== undefined && rootValue !== null && !datingValue) {
          updates[`dating.profile.${field}`] = rootValue;
          needsUpdate = true;
        }
      }

      if (needsUpdate) {
        if (isDryRun) {
          console.log(`  [DRY] ${doc.id}: ${Object.keys(updates).length} fields`);
          updated++;
        } else {
          try {
            updates['updatedAt'] = admin.firestore.FieldValue.serverTimestamp();
            await doc.ref.update(updates);
            console.log(`  ✓ ${doc.id}: migrated ${Object.keys(updates).length - 1} fields`);
            updated++;
          } catch (err) {
            console.error(`  ✗ ${doc.id}: ${err.message}`);
            errors++;
          }
        }
      } else {
        skipped++;
      }

      // Progress indicator
      if ((updated + skipped + errors) % 100 === 0) {
        console.log(`    ... processed ${updated + skipped + errors} users`);
      }
    }

    console.log(`\n${'='.repeat(70)}`);
    console.log('Migration Summary:');
    console.log(`${'='.repeat(70)}`);
    console.log(`  ✓ Updated:  ${updated}`);
    console.log(`  ⊘ Skipped:  ${skipped} (already at dating.profile)`);
    console.log(`  ✗ Errors:   ${errors}`);
    console.log(`  Total:      ${snapshot.size}`);
    console.log(`${'='.repeat(70)}`);

    if (isDryRun) {
      console.log(`\n✅ DRY RUN COMPLETE`);
      console.log(`Run with --execute to actually migrate the data\n`);
    } else {
      console.log(`\n✅ MIGRATION COMPLETE`);
      console.log(`All profile fields copied to dating.profile`);
      console.log(`Root-level fields preserved for backward compatibility\n`);
    }

  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

// Initialize Firebase
if (!admin.apps.length) {
  admin.initializeApp();
}

migrate().then(() => {
  process.exit(0);
}).catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
