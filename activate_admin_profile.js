#!/usr/bin/env node

/**
 * Activate admin profile as UK/global user and set up dating profile
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, './serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function activateAdminProfile() {
  console.log('👤 Activating admin profile for dating app...\n');

  try {
    // Find user by email
    const email = 'nexus4singles@gmail.com';
    const userQuery = await db
      .collection('users')
      .where('email', '==', email)
      .get();

    if (userQuery.empty) {
      console.error(`❌ User with email ${email} not found`);
      process.exit(1);
    }

    const userDoc = userQuery.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();

    console.log(`Found user: ${userData.displayName || 'Admin'} (${userId})`);
    console.log(`Current country: ${userData.countryOfResidence || 'Not set'}\n`);

    // Update user to be UK-based with global reach
    await userDoc.ref.update({
      countryOfResidence: 'United Kingdom',
      country: 'United Kingdom',
      city: 'London',
      isGlobalUser: true, // Mark as global so they see all markets
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ User updated to UK/Global user\n`);

    // Create dating profile if it doesn't exist
    const datingProfileRef = db.collection('datingProfiles').doc(userId);
    const datingProfileDoc = await datingProfileRef.get();

    if (!datingProfileDoc.exists) {
      console.log('📝 Creating dating profile...');
      await datingProfileRef.set({
        userId: userId,
        displayName: userData.displayName || 'Admin User',
        gender: 'male', // Admin profile set as male
        age: 35,
        city: 'London',
        countryOfResidence: 'United Kingdom',
        country: 'United Kingdom',
        bio: 'Admin testing account',
        photos: [
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop'
        ],
        verificationStatus: 'verified',
        isActive: true,
        isAdmin: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        schemaVersion: 2,
      });
      console.log(`✅ Dating profile created\n`);
    } else {
      // Update existing dating profile
      await datingProfileRef.update({
        countryOfResidence: 'United Kingdom',
        country: 'United Kingdom',
        verificationStatus: 'verified',
        isActive: true,
        gender: 'male', // Ensure admin is male to see female profiles
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`✅ Dating profile updated\n`);
    }

    // Add to daily profiles for today
    console.log('📅 Adding to daily carousel...');
    const now = new Date();
    const today = now.toISOString().split('T')[0];

    // Get all verified UK profiles for the carousel
    const allProfiles = await db
      .collection('users')
      .where('countryOfResidence', '==', 'United Kingdom')
      .where('verificationStatus', '==', 'verified')
      .get();

    const profileIds = allProfiles.docs.map(doc => doc.id);
    const carouselProfiles = profileIds
      .filter(id => id !== userId) // Don't show admin their own profile
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
        profiles: carouselProfiles,
        totalAvailable: carouselProfiles.length,
      });

    console.log(`✅ Added to daily carousel with ${carouselProfiles.length} profiles\n`);

    console.log('🎉 Admin profile is now ready!');
    console.log('\n📱 To test:');
    console.log('   1. Full app restart: flutter clean && flutter pub get && flutter run');
    console.log('   2. Log in with: nexus4singles@gmail.com');
    console.log('   3. Go to Dating/Search tab');
    console.log('   4. Should see carousel with profiles');

  } catch (error) {
    console.error('❌ Fatal error:', error.message);
    process.exit(1);
  }

  process.exit(0);
}

activateAdminProfile();
