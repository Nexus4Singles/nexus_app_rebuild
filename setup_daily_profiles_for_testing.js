#!/usr/bin/env node

/**
 * Create daily profiles test data for carousel testing
 * This simulates what the Cloud Function would generate
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, './serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function setupDailyProfiles() {
  console.log('📅 Setting up daily profiles for carousel testing...\n');
  
  try {
    // Get today's date in YYYY-MM-DD format
    const now = new Date();
    const today = now.toISOString().split('T')[0];
    console.log(`📆 Today's date: ${today}\n`);

    // Find the dummy profiles we created
    console.log('🔎 Finding dummy profiles...');
    const dummyNames = ['Amara', 'Zainab', 'Chioma', 'Tunde', 'Obi'];
    const profileIds = [];

    for (const name of dummyNames) {
      const snap = await db
        .collection('users')
        .where('displayName', '==', name)
        .where('countryOfResidence', '==', 'United Kingdom')
        .where('verificationStatus', '==', 'verified')
        .limit(1)
        .get();
      
      if (!snap.empty) {
        const docId = snap.docs[0].id;
        profileIds.push(docId);
        console.log(`   ✅ Found ${name}: ${docId}`);
      } else {
        console.log(`   ❌ Could not find ${name}`);
      }
    }

    if (profileIds.length === 0) {
      console.error('❌ No dummy profiles found! Run: node create_dummy_profiles.js');
      process.exit(1);
    }

    console.log(`\n✅ Found ${profileIds.length} profiles\n`);

    // Now we need to know which user to assign these profiles to
    // For testing, let's get the first admin user or the script runner
    console.log('👤 Looking for test user...');
    
    // Try to find any verified user to use as the test recipient
    const userSnap = await db
      .collection('users')
      .where('countryOfResidence', '==', 'United Kingdom')
      .limit(1)
      .get();

    if (userSnap.empty) {
      console.error('❌ No UK users found in database');
      process.exit(1);
    }

    const testUserId = userSnap.docs[0].id;
    const testUserData = userSnap.docs[0].data();
    console.log(`   Using test user: ${testUserId}`);
    console.log(`   Name: ${testUserData.displayName || testUserData.name || 'Unknown'}\n`);

    // Create the daily profiles document
    console.log(`📝 Creating daily profiles for ${today}...`);
    
    const profilesArray = profileIds.map((id, index) => ({
      profileId: id,
      compatibilityScore: 85 - (index * 2), // Scores: 85, 83, 81, 79, 77
      matchReason: 'Testing carousel display',
    }));

    await db
      .collection('dailyProfiles')
      .doc(today)
      .collection('users')
      .doc(testUserId)
      .set({
        uid: testUserId,
        date: today,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        profiles: profilesArray,
        totalAvailable: profileIds.length,
      });

    console.log('✅ Daily profiles created successfully!\n');
    console.log('📊 Created profiles structure:');
    console.log(`   Collection: dailyProfiles/${today}/users/${testUserId}`);
    console.log(`   Profile count: ${profileIds.length}`);
    console.log(`   Profiles:`);
    profileIds.forEach((id, index) => {
      console.log(`     ${index + 1}. ${id} (Score: ${85 - (index * 2)})`);
    });

    console.log('\n✨ Done! You can now see the carousel in the app.');
    console.log('   Make sure you:\n   1. Restart the app (flutter clean && flutter run)\n   2. Login as the UK user (if not already)\n   3. Navigate to Dating tab\n   4. Should see 5 profiles in the carousel');

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }

  process.exit(0);
}

setupDailyProfiles();
