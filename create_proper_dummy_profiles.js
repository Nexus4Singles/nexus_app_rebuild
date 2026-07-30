#!/usr/bin/env node

/**
 * Create properly structured dummy profiles for carousel testing
 * Using minimal but correct schema that DatingProfile.fromFirestore can parse
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, './serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function createProperDummyProfiles() {
  console.log('📝 Creating properly structured dummy profiles...\n');
  
  try {
    // Delete old test profiles first
    console.log('🗑️  Cleaning up old test profiles...');
    const oldProfiles = await db
      .collection('users')
      .where('displayName', 'in', ['Amara', 'Zainab', 'Chioma', 'Tunde', 'Obi'])
      .where('countryOfResidence', '==', 'United Kingdom')
      .get();
    
    for (const doc of oldProfiles.docs) {
      await doc.ref.delete();
    }
    console.log(`   Deleted ${oldProfiles.size} old profiles\n`);

    // Create properly structured profiles
    const dummyProfiles = [
      {
        displayName: 'Amara',
        gender: 'female',
        age: 28,
        city: 'London',
        countryOfResidence: 'United Kingdom',
        country: 'United Kingdom',
        verificationStatus: 'verified',
        photos: [
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&h=400&fit=crop'
        ],
        createdAt: new Date('2026-05-15'),
        isActive: true,
        schemaVersion: 2,
      },
      {
        displayName: 'Zainab',
        gender: 'female',
        age: 25,
        city: 'Manchester',
        countryOfResidence: 'United Kingdom',
        country: 'United Kingdom',
        verificationStatus: 'verified',
        photos: [
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop'
        ],
        createdAt: new Date('2026-05-20'),
        isActive: true,
        schemaVersion: 2,
      },
      {
        displayName: 'Chioma',
        gender: 'female',
        age: 30,
        city: 'Birmingham',
        countryOfResidence: 'United Kingdom',
        country: 'United Kingdom',
        verificationStatus: 'verified',
        photos: [
          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400&h=400&fit=crop'
        ],
        createdAt: new Date('2026-05-10'),
        isActive: true,
        schemaVersion: 2,
      },
      {
        displayName: 'Tunde',
        gender: 'male',
        age: 32,
        city: 'London',
        countryOfResidence: 'United Kingdom',
        country: 'United Kingdom',
        verificationStatus: 'verified',
        photos: [
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop'
        ],
        createdAt: new Date('2026-05-12'),
        isActive: true,
        schemaVersion: 2,
      },
      {
        displayName: 'Obi',
        gender: 'male',
        age: 29,
        city: 'Leeds',
        countryOfResidence: 'United Kingdom',
        country: 'United Kingdom',
        verificationStatus: 'verified',
        photos: [
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop'
        ],
        createdAt: new Date('2026-05-18'),
        isActive: true,
        schemaVersion: 2,
      },
    ];

    console.log('✏️  Creating 5 new dummy profiles...\n');
    const createdIds = [];

    for (const profile of dummyProfiles) {
      try {
        const docRef = await db.collection('users').add({
          ...profile,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        createdIds.push(docRef.id);
        console.log(`   ✅ ${profile.displayName} (${profile.gender}, ${profile.age}) - ${docRef.id}`);
      } catch (error) {
        console.error(`   ❌ Failed to create ${profile.displayName}: ${error.message}`);
      }
    }

    console.log(`\n✅ Created ${createdIds.length}/5 profiles\n`);

    if (createdIds.length === 0) {
      console.error('❌ No profiles created!');
      process.exit(1);
    }

    // Now update the daily profiles with the new IDs
    console.log('📅 Updating daily profiles for carousel...');
    const now = new Date();
    const today = now.toISOString().split('T')[0];
    
    // Find any UK user to use as the test recipient
    const testUserSnap = await db
      .collection('users')
      .where('countryOfResidence', '==', 'United Kingdom')
      .limit(1)
      .get();

    if (testUserSnap.empty) {
      console.error('❌ No UK users found');
      process.exit(1);
    }

    const testUserId = testUserSnap.docs[0].id;
    const testUserName = testUserSnap.docs[0].data().displayName || 'Unknown';
    console.log(`   Using test user: ${testUserName} (${testUserId})\n`);

    // Create daily profiles with the new IDs
    const profilesArray = createdIds.map((id, index) => ({
      profileId: id,
      compatibilityScore: 85 - (index * 2),
      matchReason: 'Test profile for carousel',
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
        totalAvailable: createdIds.length,
      });

    console.log(`📊 Daily profiles created for ${today}`);
    console.log(`   Collection: dailyProfiles/${today}/users/${testUserId}`);
    console.log(`   Total profiles: ${createdIds.length}\n`);

    console.log('✨ Done! The carousel should now work.');
    console.log('\n🚀 Next steps:');
    console.log('   1. Do a full app restart:');
    console.log('      flutter clean && flutter pub get && flutter run');
    console.log('   2. Navigate to Dating/Search tab');
    console.log('   3. You should see the carousel with 5 profiles');

  } catch (error) {
    console.error('❌ Fatal error:', error.message);
    process.exit(1);
  }

  process.exit(0);
}

createProperDummyProfiles();
