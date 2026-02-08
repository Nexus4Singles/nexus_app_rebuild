#!/usr/bin/env node

/**
 * Verify eligible V1 users by setting dating.verificationStatus to 'verified'
 * 
 * V1 users must meet ALL of these criteria to be eligible for V2:
 *   1. schemaVersion < 2 or schemaVersion == null
 *   2. Must have at least one photo (photos array non-empty)
 *   3. Must have registration_progress == 'completed'
 *   4. Must have compatibility_setted == true (completed compatibility quiz)
 * 
 * Only eligible V1 users will be verified.
 * 
 * Usage:
 *   node verify_all_v1_users.js [--dry-run]
 * 
 * Examples:
 *   node verify_all_v1_users.js --dry-run    # Preview changes without applying
 *   node verify_all_v1_users.js              # Apply verification to eligible V1 users
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '../serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();
const auth = admin.auth();

const isDryRun = process.argv.includes('--dry-run');

/**
 * Check if a V1 user is eligible for V2
 * Must meet ALL criteria:
 * 1. Has photos (non-empty array)
 * 2. registration_progress == 'completed'
 * 3. compatibility_setted == true
 */
function isEligibleV1User(data) {
  // Check for photos
  const photos = data.photos;
  const hasPhotos = Array.isArray(photos) && photos.length > 0;
  if (!hasPhotos) return { eligible: false, reason: 'no photos' };

  // Check registration_progress
  const reg = (data.registration_progress ?? '').toString().toLowerCase().trim();
  if (reg !== 'completed') return { eligible: false, reason: `registration_progress="${reg}"` };

  // Check compatibility_setted (must have completed quiz)
  if (data.compatibility_setted !== true) {
    return { eligible: false, reason: 'compatibility_setted not true' };
  }

  return { eligible: true, reason: null };
}

async function verifyEligibleV1Users() {
  console.log('🔍 Starting V1 user eligibility check and verification...');
  console.log(`Mode: ${isDryRun ? 'DRY RUN (no changes)' : 'LIVE (will verify eligible users)'}\n`);

  try {
    // Query all users with schemaVersion < 2
    const usersRef = db.collection('users');
    
    // First, get all users with schemaVersion < 2
    const legacyQuery = usersRef.where('schemaVersion', '<', 2);
    const legacySnap = await legacyQuery.get();
    
    // Second, get all users where schemaVersion is missing (null)
    const allUsersSnap = await usersRef.limit(10000).get();
    
    const allV1Users = [];
    const seen = new Set();
    
    // Collect users with schemaVersion < 2
    legacySnap.forEach(doc => {
      allV1Users.push(doc);
      seen.add(doc.id);
    });
    
    // Collect users where schemaVersion is missing
    allUsersSnap.forEach(doc => {
      if (!seen.has(doc.id)) {
        const sv = doc.data().schemaVersion;
        if (sv === undefined || sv === null) {
          allV1Users.push(doc);
          seen.add(doc.id);
        }
      }
    });
    
    console.log(`📊 Found ${allV1Users.length} total V1 users (schemaVersion missing/< 2)\n`);
    
    // Filter by eligibility criteria
    const eligibleUsers = [];
    const ineligibleUsers = [];
    
    allV1Users.forEach(doc => {
      const data = doc.data();
      const check = isEligibleV1User(data);
      
      if (check.eligible) {
        eligibleUsers.push(doc);
      } else {
        ineligibleUsers.push({ doc, reason: check.reason });
      }
    });
    
    console.log(`✅ Eligible for V2: ${eligibleUsers.length} users`);
    console.log(`❌ Ineligible for V2: ${ineligibleUsers.length} users\n`);
    
    // Show ineligibility breakdown
    if (ineligibleUsers.length > 0) {
      const reasons = {};
      ineligibleUsers.forEach(({ reason }) => {
        reasons[reason] = (reasons[reason] || 0) + 1;
      });
      console.log('Ineligibility breakdown:');
      Object.entries(reasons).forEach(([reason, count]) => {
        console.log(`  - ${reason}: ${count} users`);
      });
      console.log();
    }
    
    if (eligibleUsers.length === 0) {
      console.log('✅ No eligible V1 users found to verify');
      return;
    }
    
    // Preview first 5 eligible users
    console.log('📋 Sample of eligible V1 users to verify:');
    eligibleUsers.slice(0, 5).forEach((doc, idx) => {
      const data = doc.data();
      const sv = data.schemaVersion ?? 'missing';
      const username = data.username || data.name || data.email || 'N/A';
      const photoCount = (data.photos && Array.isArray(data.photos)) ? data.photos.length : 0;
      const currentStatus = data.dating?.verificationStatus || 'unset';
      console.log(`  ${idx + 1}. ${doc.id} (${username}) - photos: ${photoCount}, status: ${currentStatus}`);
    });
    
    if (eligibleUsers.length > 5) {
      console.log(`  ... and ${eligibleUsers.length - 5} more\n`);
    } else {
      console.log();
    }
    
    if (isDryRun) {
      console.log('⏸️  DRY RUN: No changes will be made');
      console.log(`Would verify ${eligibleUsers.length} eligible V1 users\n`);
      return;
    }
    
    // Confirm before proceeding
    console.log('⚠️  WARNING: This will verify all eligible V1 users');
    console.log('Type "yes" to proceed with verification...\n');
    
    // For non-interactive testing, accept via env variable
    if (process.env.SKIP_CONFIRM !== 'true') {
      const readline = require('readline');
      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
      });
      
      await new Promise(resolve => {
        rl.question('Proceed? (yes/no): ', answer => {
          rl.close();
          if (answer.toLowerCase() !== 'yes') {
            console.log('❌ Verification cancelled');
            process.exit(0);
          }
          resolve();
        });
      });
    }
    
    console.log('\n✍️  Verifying eligible V1 users...\n');
    
    const batch = db.batch();
    let processed = 0;
    const adminId = 'system-auto-verify';
    const now = admin.firestore.FieldValue.serverTimestamp();
    
    eligibleUsers.forEach(doc => {
      const updateData = {
        'dating.verificationStatus': 'verified',
        'dating.verifiedAt': now,
        'dating.verifiedBy': adminId,
        'dating.reviewedBy': adminId,
        'dating.reviewedAt': now,
      };
      
      batch.update(doc.ref, updateData);
      processed++;
      
      // Firestore batch has limit of 500 writes
      if (processed % 500 === 0) {
        console.log(`📝 Processed ${processed} users so far...`);
      }
    });
    
    // Commit the batch
    await batch.commit();
    
    console.log(`\n✅ Successfully verified ${eligibleUsers.length} eligible V1 users`);
    console.log('   - Set dating.verificationStatus = "verified"');
    console.log('   - Set verifiedAt timestamp');
    console.log('   - Set verifiedBy = "system-auto-verify"');
    console.log(`   - Set reviewedAt timestamp\n`);
    
    console.log('📊 Summary:');
    console.log(`   Total V1 users found: ${allV1Users.length}`);
    console.log(`   Eligible (verified now): ${eligibleUsers.length}`);
    console.log(`   Ineligible (not verified): ${ineligibleUsers.length}`);
    
  } catch (error) {
    console.error('❌ Error during verification:', error);
    process.exit(1);
  }
}

// Run the script
verifyEligibleV1Users()
  .then(() => {
    console.log('\n✨ Done!');
    process.exit(0);
  })
  .catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
