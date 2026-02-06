#!/usr/bin/env node

/**
 * Firestore Schema Restructure Script
 * Organizes user data into logical subcollections
 * 
 * Transforms from flat structure to organized structure:
 * - Creates users/{uid}/profile document
 * - Creates users/{uid}/dating document  
 * - Creates users/{uid}/compatibility document
 * - Moves assessments to users/{uid}/assessments collection
 * - Moves journeys to users/{uid}/journeys collection
 * - Creates users/{uid}/verification document
 * - Creates users/{uid}/stories collection
 * - Creates users/{uid}/polls collection
 * 
 * Usage: node scripts/restructure_schema.js [--dry-run]
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
const dryRun = process.argv.includes('--dry-run');

if (dryRun) {
  console.log('🔍 DRY RUN MODE - No changes will be made\n');
}

/**
 * Define which top-level user fields go to which subcollections
 */
const STRUCTURE_MAPPING = {
  profile: {
    fields: ['name', 'dateOfBirth', 'gender', 'country', 'city', 'state', 'displayName'],
    description: 'Basic identity and profile info'
  },
  dating: {
    fields: ['dating'], // Move entire dating object
    description: 'Dating-specific data'
  },
  compatibility: {
    fields: ['compatibility', 'maritalStatus'],
    description: 'Compatibility preferences and data'
  },
  verification: {
    fields: ['verification', 'verificationStatus', 'verificationReviewedAt'],
    description: 'Verification workflow state'
  },
  settings: {
    fields: ['settings', 'privacy', 'notifications'],
    description: 'User settings and preferences'
  }
};

/**
 * Collections to migrate from root to user subcollection
 */
const COLLECTIONS_TO_MIGRATE = [
  { from: 'assessments', to: 'assessments', description: 'User assessments' },
  { from: 'journeyProgress', to: 'journeys', description: 'User journeys and progress' },
  { from: 'stories', to: 'stories', description: 'User stories' },
  { from: 'polls', to: 'polls', description: 'User polls' }
];

async function getOrCreateSubdocument(uid, subcollectionName, data) {
  const docRef = db.collection('users').doc(uid).collection(subcollectionName).doc('data');
  
  if (!dryRun) {
    await docRef.set(data, { merge: true });
  }
  
  return docRef;
}

async function migrateField(uid, fromPath, toPath, value) {
  console.log(`      Migrating ${fromPath} → ${toPath}`);
  
  if (!dryRun) {
    const parts = toPath.split('.');
    let updateData = {};
    let current = updateData;
    
    for (let i = 0; i < parts.length - 1; i++) {
      current[parts[i]] = {};
      current = current[parts[i]];
    }
    
    current[parts[parts.length - 1]] = value;
    
    // Set in the appropriate document
    const docRef = db.collection('users').doc(uid);
    await docRef.update(updateData);
  }
}

async function migrateCollection(uid, fromPath, toPath) {
  console.log(`      Migrating collection: ${fromPath} → users/{uid}/${toPath}`);
  
  try {
    const snapshot = await db.collection('users').doc(uid).collection(fromPath).get();
    
    if (!dryRun && snapshot.docs.length > 0) {
      const batch = db.batch();
      
      for (const doc of snapshot.docs) {
        const newDocRef = db.collection('users').doc(uid).collection(toPath).doc(doc.id);
        batch.set(newDocRef, doc.data());
      }
      
      await batch.commit();
    }
    
    console.log(`        ✓ Migrated ${snapshot.docs.length} documents`);
  } catch (error) {
    console.log(`        ⚠️  Collection ${fromPath} not found or empty`);
  }
}

async function restructureUser(uid, userData) {
  console.log(`\n📝 Restructuring user: ${uid}`);
  
  const updates = {};
  
  // 1. Create profile document
  console.log(`   Creating profile document`);
  const profileData = {};
  for (const field of STRUCTURE_MAPPING.profile.fields) {
    if (field in userData) {
      profileData[field] = userData[field];
      updates[field] = admin.firestore.FieldValue.delete(); // Remove from root
    }
  }
  if (Object.keys(profileData).length > 0) {
    if (!dryRun) {
      await db.collection('users').doc(uid).collection('profile').doc('data').set(profileData, { merge: true });
    }
    console.log(`      ✓ Created profile document`);
  }

  // 2. Move dating object (already nested, just ensure it exists)
  console.log(`   Verifying dating document`);
  if ('dating' in userData) {
    if (!dryRun) {
      await db.collection('users').doc(uid).collection('dating').doc('data').set(userData.dating, { merge: true });
    }
    console.log(`      ✓ Dating document ready`);
  }

  // 3. Create compatibility document
  console.log(`   Creating compatibility document`);
  const compatData = {};
  for (const field of STRUCTURE_MAPPING.compatibility.fields) {
    if (field in userData) {
      compatData[field] = userData[field];
      updates[field] = admin.firestore.FieldValue.delete(); // Remove from root
    }
  }
  if (Object.keys(compatData).length > 0) {
    if (!dryRun) {
      await db.collection('users').doc(uid).collection('compatibility').doc('data').set(compatData, { merge: true });
    }
    console.log(`      ✓ Created compatibility document`);
  }

  // 4. Create verification document
  console.log(`   Creating verification document`);
  const verifyData = {};
  for (const field of STRUCTURE_MAPPING.verification.fields) {
    if (field in userData) {
      verifyData[field] = userData[field];
      updates[field] = admin.firestore.FieldValue.delete(); // Remove from root
    }
  }
  if (Object.keys(verifyData).length > 0) {
    if (!dryRun) {
      await db.collection('users').doc(uid).collection('verification').doc('data').set(verifyData, { merge: true });
    }
    console.log(`      ✓ Created verification document`);
  }

  // 5. Migrate collections
  console.log(`   Migrating collections`);
  for (const collection of COLLECTIONS_TO_MIGRATE) {
    await migrateCollection(uid, collection.from, collection.to);
  }

  // 6. Apply root-level field deletions
  if (Object.keys(updates).length > 0 && !dryRun) {
    await db.collection('users').doc(uid).update(updates);
  }

  console.log(`   ✅ User restructuring complete`);
}

async function restructureSchema() {
  console.log('🔄 Starting schema restructure...\n');

  const usersSnapshot = await db.collection('users').get();
  console.log(`📊 Found ${usersSnapshot.size} user documents to restructure\n`);

  let totalProcessed = 0;
  let totalErrors = 0;

  for (const userDoc of usersSnapshot.docs) {
    try {
      await restructureUser(userDoc.id, userDoc.data());
      totalProcessed++;
    } catch (error) {
      console.error(`❌ Error restructuring user ${userDoc.id}: ${error.message}`);
      totalErrors++;
    }
  }

  console.log('\n' + '='.repeat(50));
  console.log('📋 Restructure Summary:');
  console.log(`   Total users processed: ${totalProcessed}`);
  console.log(`   Errors: ${totalErrors}`);
  console.log('='.repeat(50));

  if (dryRun) {
    console.log('\n🔍 DRY RUN completed - no changes made');
  } else {
    console.log('\n✅ Schema restructure complete!');
    console.log('\n📝 Next steps:');
    console.log('   1. Update Firestore rules for new structure');
    console.log('   2. Update app code to read from new paths');
    console.log('   3. Test all features in staging');
    console.log('   4. Gradually roll out to production');
  }

  await admin.app().delete();
}

// Run the script
restructureSchema().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
