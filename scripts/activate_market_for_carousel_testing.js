#!/usr/bin/env node

/**
 * Temporarily activate the UK market for carousel testing
 * This allows you to see how dummy profiles render on the daily profiles carousel
 * 
 * Usage: node scripts/activate_market_for_carousel_testing.js
 * 
 * After testing, run: node scripts/revert_market_to_prelaunch.js
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

async function activateMarketForTesting() {
  try {
    console.log('🚀 Activating UK market for carousel testing...\n');

    // Get current market data
    const marketRef = db.collection('markets').doc('uk');
    const marketDoc = await marketRef.get();

    if (!marketDoc.exists) {
      console.error('❌ Market document not found. Initialize with: node scripts/initialize_market.js uk');
      process.exit(1);
    }

    const currentData = marketDoc.data();
    console.log('Current market state:');
    console.log(`  Phase: ${currentData.phase}`);
    console.log(`  Launch Date: ${currentData.launchDate ? currentData.launchDate.toDate() : 'Not set'}`);
    console.log(`  Approved Profiles: ${currentData.approvedProfileCount}\n`);

    // Update market phase to active
    await marketRef.update({
      phase: 'active',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('✅ Market activated successfully!\n');
    console.log('📱 Next steps:');
    console.log('  1. Open your app');
    console.log('  2. Navigate to Search/Dating tab');
    console.log('  3. You should see the carousel with your dummy profiles');
    console.log('  4. Review the carousel design and profile rendering');
    console.log('\n🔄 To revert back to prelaunch:');
    console.log('   node scripts/revert_market_to_prelaunch.js\n');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error activating market:', error.message);
    process.exit(1);
  }
}

activateMarketForTesting();
