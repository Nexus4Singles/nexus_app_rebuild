#!/usr/bin/env node

/**
 * Debug script to verify Firestore creation and permissions
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase
const serviceAccountPath = path.join(__dirname, './serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function debugFirestore() {
  console.log('🔍 Firestore Debug Script\n');
  
  try {
    // 1. Check Firebase project
    console.log('📱 Firebase Project ID:', serviceAccount.project_id);
    console.log('📧 Service Account Email:', serviceAccount.client_email);
    console.log('');

    // 2. Count existing users
    console.log('📊 Checking existing users collection...');
    const usersSnap = await db.collection('users').limit(100).get();
    console.log(`   Total users found: ${usersSnap.size}`);
    
    // List first 5 users
    if (usersSnap.size > 0) {
      console.log('\n   First few users:');
      usersSnap.docs.slice(0, 5).forEach(doc => {
        const data = doc.data();
        console.log(`   - ${doc.id}: ${data.displayName || data.name || 'Unknown'} (${data.gender || 'N/A'})`);
      });
    }
    console.log('');

    // 3. Try creating a single test profile with full error details
    console.log('✏️  Attempting to create test profile...');
    const testProfile = {
      displayName: 'DEBUG_TEST_' + Date.now(),
      gender: 'Female',
      age: 25,
      verificationStatus: 'verified',
      countryOfResidence: 'United Kingdom',
      city: 'London',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const docRef = await db.collection('users').add(testProfile);
    console.log('✅ Test profile created successfully!');
    console.log(`   Document ID: ${docRef.id}`);
    console.log('');

    // 4. Verify the profile was actually written
    console.log('🔎 Verifying test profile in Firestore...');
    const verifySnap = await docRef.get();
    if (verifySnap.exists) {
      console.log('✅ Profile verified in Firestore:');
      console.log('   ', verifySnap.data());
    } else {
      console.log('❌ Profile NOT found in Firestore after creation!');
    }
    console.log('');

    // 5. Try updating the gender stats
    console.log('📊 Attempting to update gender statistics...');
    const statsRef = db
      .collection('config')
      .doc('waitingListStats')
      .collection('countries')
      .doc('United Kingdom');

    await statsRef.set({
      maleCount: 999,
      femaleCount: 888,
      totalCount: 1887,
      lastUpdated: new Date().toISOString(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log('✅ Stats update command sent');

    // 6. Verify stats were written
    console.log('🔎 Verifying stats in Firestore...');
    const statsSnap = await statsRef.get();
    if (statsSnap.exists) {
      console.log('✅ Stats verified in Firestore:');
      console.log('   ', statsSnap.data());
    } else {
      console.log('❌ Stats document NOT found!');
    }

    console.log('\n✨ Debug complete. Firestore is working correctly if you see the test profile above.');

  } catch (error) {
    console.error('❌ Error during debug:', error.message);
    console.error('\nFull error:');
    console.error(error);
  }

  process.exit(0);
}

debugFirestore();
