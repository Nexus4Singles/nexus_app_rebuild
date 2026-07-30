#!/usr/bin/env node

/**
 * Search for the dummy profiles we created
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, './serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function findDummyProfiles() {
  console.log('🔍 Searching for dummy profiles...\n');
  
  try {
    // Search for profiles by displayName
    const names = ['Amara', 'Zainab', 'Chioma', 'Tunde', 'Obi'];
    
    for (const name of names) {
      console.log(`🔎 Searching for "${name}"...`);
      const snap = await db
        .collection('users')
        .where('displayName', '==', name)
        .get();
      
      if (snap.empty) {
        console.log(`   ❌ Not found\n`);
      } else {
        snap.docs.forEach(doc => {
          const data = doc.data();
          console.log(`   ✅ Found! ID: ${doc.id}`);
          console.log(`      Gender: ${data.gender}`);
          console.log(`      Age: ${data.age}`);
          console.log(`      City: ${data.city}`);
          console.log('');
        });
      }
    }

    // Also count profiles with verification status 'verified' and UK residence
    console.log('📊 Searching for verified UK profiles...');
    const ukSnap = await db
      .collection('users')
      .where('countryOfResidence', '==', 'United Kingdom')
      .where('verificationStatus', '==', 'verified')
      .limit(20)
      .get();
    
    console.log(`   Found ${ukSnap.size} verified UK profiles\n`);
    
    if (ukSnap.size > 0) {
      console.log('   Recent ones:');
      ukSnap.docs.forEach(doc => {
        const data = doc.data();
        console.log(`   - ${data.displayName || 'Unknown'} (${data.gender}, age ${data.age})`);
      });
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
  }

  process.exit(0);
}

findDummyProfiles();
