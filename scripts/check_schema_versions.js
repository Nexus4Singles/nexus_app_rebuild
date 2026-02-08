#!/usr/bin/env node

/**
 * Check actual schemaVersion values in the database
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, '../serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();

async function checkSchemaVersions() {
  console.log('🔍 Checking schemaVersion distribution...\n');

  try {
    // Get a sample of users to see their schemaVersions
    const snap = await db.collection('users').limit(100).get();
    
    const schemaVersions = {};
    let missingSchemaCount = 0;
    
    snap.forEach(doc => {
      const sv = doc.data().schemaVersion;
      if (sv === undefined || sv === null) {
        missingSchemaCount++;
      } else {
        const svStr = String(sv);
        schemaVersions[svStr] = (schemaVersions[svStr] || 0) + 1;
      }
    });
    
    console.log('📊 Schema versions found in sample of 100 users:');
    console.log(`   Missing schemaVersion: ${missingSchemaCount}`);
    Object.entries(schemaVersions).sort().forEach(([sv, count]) => {
      console.log(`   schemaVersion ${sv}: ${count} users`);
    });
    
    console.log(`\nTotal sampled: ${snap.size}`);
    
    // Now check for users who have dating.verificationStatus already set
    const verifiedSnap = await db
      .collection('users')
      .where('dating.verificationStatus', '==', 'verified')
      .limit(3)
      .get();
    
    console.log(`\n✅ Users already verified (sample):`);
    verifiedSnap.forEach(doc => {
      const data = doc.data();
      console.log(`  ${doc.id}: sv=${data.schemaVersion}, status=${data.dating?.verificationStatus}`);
    });
    
    // Check for unverified users
    const unverifiedSnap = await db
      .collection('users')
      .where('dating.verificationStatus', '==', 'unverified')
      .limit(3)
      .get();
    
    console.log(`\n❌ Users still unverified (sample):`);
    unverifiedSnap.forEach(doc => {
      const data = doc.data();
      console.log(`  ${doc.id}: sv=${data.schemaVersion}, status=${data.dating?.verificationStatus}`);
    });
    
    // Check what other verification statuses exist
    const allUsersSnap = await db.collection('users').limit(500).get();
    const statuses = new Set();
    allUsersSnap.forEach(doc => {
      const status = doc.data().dating?.verificationStatus;
      if (status) statuses.add(status);
    });
    
    console.log(`\n📋 All verification statuses in database:`);
    statuses.forEach(s => console.log(`   - "${s}"`));
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

checkSchemaVersions()
  .then(() => {
    console.log('\n✨ Done!');
    process.exit(0);
  })
  .catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
