#!/usr/bin/env node

/**
 * Create daily profiles for ALL verified UK users
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, './serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function createDailyProfilesForAllUsers() {
  console.log('📅 Creating daily profiles for ALL UK users...\n');

  try {
    // Get all verified UK users
    const allUKUsers = await db
      .collection('users')
      .where('countryOfResidence', '==', 'United Kingdom')
      .where('verificationStatus', '==', 'verified')
      .get();

    console.log(`Found ${allUKUsers.size} verified UK users\n`);

    // Get all verified UK profiles (to create carousel options)
    const carouselProfiles = await db
      .collection('users')
      .where('countryOfResidence', '==', 'United Kingdom')
      .where('verificationStatus', '==', 'verified')
      .get();

    const profileIds = carouselProfiles.docs.map(doc => doc.id);
    console.log(`${profileIds.length} profiles available for carousel\n`);

    // Get today's date
    const now = new Date();
    const today = now.toISOString().split('T')[0];
    console.log(`Setting up for date: ${today}\n`);

    // Create daily profiles for each user
    let successCount = 0;
    for (const userDoc of allUKUsers.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      const userName = userData.displayName || 'Unknown';

      try {
        // Create an array of all OTHER profiles for this user's carousel
        const carouselForThisUser = profileIds
          .filter(id => id !== userId) // Don't show user their own profile
          .map((id, index) => ({
            profileId: id,
            compatibilityScore: 85 - (index % 10),
            matchReason: 'Daily match recommendation',
          }));

        await db
          .collection('dailyProfiles')
          .doc(today)
          .collection('users')
          .doc(userId)
          .set({
            uid: userId,
            date: today,
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            profiles: carouselForThisUser,
            totalAvailable: carouselForThisUser.length,
          });

        console.log(`✅ ${userName} (${userId})`);
        successCount++;
      } catch (error) {
        console.error(`❌ ${userName}: ${error.message}`);
      }
    }

    console.log(`\n✨ Created daily profiles for ${successCount}/${allUKUsers.size} users`);
    console.log('\n🚀 Now:');
    console.log('   1. Full app restart: flutter clean && flutter pub get && flutter run');
    console.log('   2. Go to Dating/Search tab');
    console.log('   3. Carousel should show');

  } catch (error) {
    console.error('❌ Fatal error:', error.message);
    process.exit(1);
  }

  process.exit(0);
}

createDailyProfilesForAllUsers();
