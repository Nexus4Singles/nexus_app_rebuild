#!/usr/bin/env node

/**
 * Firestore Schema Cleanup Script
 * Removes duplicate fields that are not used in code
 * 
 * Safe Duplicates Being Removed:
 * - photos[] (top-level) → Keep dating.photos[]
 * - dating.gender → Keep gender
 * - dating.contactInfo.Instagram → Keep instagramUsername
 * - dating.contactInfo.countryOfResidence → Keep country
 * - nexus.relationshipStatus → Keep dating.relationshipStatus
 * - nexus.gender → Keep gender
 * - nexus.photos → Keep dating.photos[]
 * 
 * Usage: node scripts/remove_duplicate_fields.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase
const serviceAccount = require(path.join(__dirname, '../serviceAccount.json'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();

// Define which fields to remove from which documents
const REMOVALS = [
  {
    path: 'users',
    removeFields: ['photos'], // Top-level photos[]
    description: 'Remove top-level photos[] (use dating.photos[] instead)'
  },
  {
    path: 'users',
    nestedPath: 'dating',
    removeFields: ['gender', 'reviewPack.audioUrls', 'reviewPack.photoUrls'],
    description: 'Remove gender and old reviewPack URLs from dating object'
  },
  {
    path: 'users',
    nestedPath: 'dating.contactInfo',
    removeFields: ['Instagram', 'countryOfResidence'],
    description: 'Remove Instagram and countryOfResidence from dating.contactInfo'
  },
  {
    path: 'users',
    nestedPath: 'nexus',
    removeFields: ['relationshipStatus', 'gender', 'photos'],
    description: 'Remove legacy nexus fields'
  }
];

async function removeFields() {
  console.log('🔄 Starting duplicate field removal...\n');

  let totalUpdated = 0;
  let totalErrors = 0;

  // Get all users
  const usersSnapshot = await db.collection('users').get();
  console.log(`📊 Found ${usersSnapshot.size} user documents to process\n`);

  for (const userDoc of usersSnapshot.docs) {
    const uid = userDoc.id;
    const userData = userDoc.data();
    let updateData = {};
    let hasChanges = false;

    // Process each removal rule
    for (const removal of REMOVALS) {
      console.log(`   Processing: ${removal.description}`);

      if (removal.nestedPath) {
        // For nested fields like dating.gender
        const parts = removal.nestedPath.split('.');
        let nestedObj = userData;

        // Navigate to the nested object
        for (const part of parts) {
          if (nestedObj && typeof nestedObj === 'object') {
            nestedObj = nestedObj[part];
          } else {
            nestedObj = null;
            break;
          }
        }

        if (nestedObj && typeof nestedObj === 'object') {
          // Build the update path
          for (const field of removal.removeFields) {
            if (field in nestedObj) {
              const updatePath = `${removal.nestedPath}.${field}`;
              updateData[updatePath] = admin.firestore.FieldValue.delete();
              hasChanges = true;
              console.log(`      ✓ Will remove: ${updatePath}`);
            }
          }
        }
      } else {
        // For top-level fields
        for (const field of removal.removeFields) {
          if (field in userData) {
            updateData[field] = admin.firestore.FieldValue.delete();
            hasChanges = true;
            console.log(`      ✓ Will remove: ${field}`);
          }
        }
      }
    }

    // Update the document if there are changes
    if (hasChanges) {
      try {
        await db.collection('users').doc(uid).update(updateData);
        totalUpdated++;
        console.log(`   ✅ Updated user ${uid}\n`);
      } catch (error) {
        totalErrors++;
        console.error(`   ❌ Error updating user ${uid}: ${error.message}\n`);
      }
    } else {
      console.log(`   ⏭️  No duplicate fields found in user ${uid}\n`);
    }
  }

  console.log('\n📋 Summary:');
  console.log(`   Total users processed: ${usersSnapshot.size}`);
  console.log(`   Successfully updated: ${totalUpdated}`);
  console.log(`   Errors: ${totalErrors}`);

  if (totalUpdated > 0) {
    console.log('\n✅ Duplicate field removal complete!');
  } else {
    console.log('\n✅ No duplicate fields found to remove.');
  }

  await admin.app().delete();
}

// Run the script
removeFields().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
