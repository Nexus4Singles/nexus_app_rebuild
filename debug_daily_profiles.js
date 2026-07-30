#!/usr/bin/env node

/**
 * Debug daily profiles structure
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, './serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function debugDailyProfiles() {
  console.log('🔍 Debugging daily profiles structure...\n');

  try {
    // Check what's in dailyProfiles collection directly
    console.log('📅 Checking dailyProfiles collection...');
    const now = new Date();
    const today = now.toISOString().split('T')[0];
    console.log(`   Looking for today: ${today}\n`);
    
    // Check if today's doc exists
    const todayDoc = await db.collection('dailyProfiles').doc(today).get();
    if (!todayDoc.exists) {
      console.log(`   ⚠️  Document for ${today} doesn't exist`);
    } else {
      console.log(`   ✅ Found dailyProfiles/${today}\n`);
    }

    // Get all users under today
    const userDocs = await db
      .collection('dailyProfiles')
      .doc(today)
      .collection('users')
      .get();
    
    console.log(`   Users with daily profiles: ${userDocs.size}`);
    for (const doc of userDocs.docs) {
      const data = doc.data();
      console.log(`   - User: ${doc.id}`);
      console.log(`     Profiles array: ${data.profiles?.length || 0} items`);
      if (data.profiles?.length > 0) {
        console.log(`     Profiles: ${JSON.stringify(data.profiles, null, 2)}`);
      }
    }

    // Also check UK users to see which ones exist
    console.log('\n🇬🇧 Checking UK users...');
    const ukUsers = await db
      .collection('users')
      .where('countryOfResidence', '==', 'United Kingdom')
      .where('verificationStatus', '==', 'verified')
      .get();
    
    console.log(`   Found ${ukUsers.size} verified UK users:`);
    for (const doc of ukUsers.docs) {
      const data = doc.data();
      console.log(`   - ${data.displayName} (${doc.id}) - ${data.gender}`);
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
  }

  process.exit(0);
}

debugDailyProfiles();
