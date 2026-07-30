#!/usr/bin/env node

/**
 * Revert the UK market back to prelaunch after carousel testing
 * 
 * Usage: node scripts/revert_market_to_prelaunch.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase
const serviceAccountPath = path.join(__dirname, '../serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-app-v2-default-rtdb.firebaseio.com',
});

const db = admin.firestore();

async function revertMarketToPrelaunch() {
  try {
    console.log('⏮️  Reverting UK market to prelaunch...\n');

    const marketRef = db.collection('markets').doc('uk');
    const marketDoc = await marketRef.get();

    if (!marketDoc.exists) {
      console.error('❌ Market document not found.');
      process.exit(1);
    }

    const currentData = marketDoc.data();
    console.log('Current market state:');
    console.log(`  Phase: ${currentData.phase}`);
    console.log(`  Launch Date: ${currentData.launchDate ? currentData.launchDate.toDate() : 'Not set'}\n`);

    // Revert phase to prelaunch
    await marketRef.update({
      phase: 'prelaunch',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('✅ Market reverted to prelaunch!\n');
    console.log('📱 When you open the app next, users will see the waiting list again.\n');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error reverting market:', error.message);
    process.exit(1);
  }
}

revertMarketToPrelaunch();
