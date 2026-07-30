#!/usr/bin/env node

/**
 * Create ~20 UK dummy profiles for the prelaunch + daily profiles flow.
 *
 * What this script does:
 * 1. Creates 20 user docs with mostly realistic UK dating profile fields.
 * 2. Ensures the docs are visible to the daily-profile provider by writing the
 *    common fields it reads: gender, countryOfResidence, verificationStatus,
 *    photos, and dating.profile.country / dating.verificationStatus.
 * 3. Seeds a dailyProfiles/{today}/users/{targetUserId} doc for one test user so
 *    the app can show the daily carousel immediately.
 * 4. Creates/updates a UK market document in Firestore with phase 'active' so the
 *    router shows the daily profiles screen for UK users.
 *
 * Usage:
 *   node scripts/create_uk_dummy_profiles.js
 */

const path = require('path');
const admin = require('firebase-admin');

const serviceAccountPath = path.join(__dirname, '..', 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();
const today = new Date().toISOString().split('T')[0];
const tomorrow = new Date();
tomorrow.setDate(tomorrow.getDate() + 1);
const tomorrowStr = tomorrow.toISOString().split('T')[0];

const firstNames = [
  'Aisha','Amelia','Beth','Chloe','Daisy','Ella','Fiona','Grace','Hannah','Isla',
  'Jasmine','Kira','Lola','Maya','Naomi','Olivia','Phoebe','Riley','Sophie','Talia',
  'Uma','Vera','Willow','Xara','Yara','Zara','Ava','Brooke','Cora','Diana'
];
const maleFirstNames = [
  'Aaron','Ben','Callum','Daniel','Ethan','Felix','George','Hugo','Isaac','Jack',
  'Kai','Lewis','Mason','Noah','Owen','Parker','Quentin','Rory','Sam','Theo','Uri','Vince','Wes','Xander','Yusuf','Zane'
];
const surnames = [
  'Adams','Baker','Clark','Dawson','Ellis','Foster','Graham','Hughes','Irwin','Jones',
  'Khan','Lee','Morgan','Norris','Osei','Parker','Quinn','Reed','Simmons','Taylor','Underwood','Vega','Walker','Xavier','Young','Zane'
];
const cities = ['London','Manchester','Birmingham','Leeds','Bristol','Glasgow','Liverpool','Sheffield','Edinburgh','Cardiff'];
const photos = [
  'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1504593811423-6dd665756598?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1554151228-14d9def656e4?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=800&q=80',
];

function randomFrom(list) {
  return list[Math.floor(Math.random() * list.length)];
}

function buildProfile(index, gender) {
  const firstName = gender === 'female' ? randomFrom(firstNames) : randomFrom(maleFirstNames);
  const lastName = randomFrom(surnames);
  const city = randomFrom(cities);
  const age = 22 + (index % 12);
  const displayName = `${firstName} ${lastName}`;
  const photoList = [
    photos[index % photos.length],
    photos[(index + 2) % photos.length],
    photos[(index + 5) % photos.length],
  ];

  return {
    name: displayName,
    displayName,
    gender,
    age,
    city,
    countryOfResidence: 'United Kingdom',
    country: 'United Kingdom',
    verificationStatus: 'verified',
    photos: photoList,
    isActive: true,
    isDummyProfile: true,
    dummyProfileOrigin: 'uk_prelaunch_test',
    isTestData: true,
    schemaVersion: 2,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    status: 'active',
    dating: {
      profile: {
        country: 'United Kingdom',
      },
      countryOfResidence: 'United Kingdom',
      verificationStatus: 'verified',
    },
    compatibility: {
      shouldChristianSpeakInTongue: 'yes',
      believeInTithing: 'yes',
      haveKids: 'no',
      longDistance: 'yes',
      believeInCohabiting: 'yes',
      genotype: 'AA',
      personalityType: 'Intuitive',
      regularSourceOfIncome: 'yes',
      marrySomeoneNotFS: 'no',
    },
    compatibilitySetted: true,
    interestedInDating: true,
    email: `${firstName.toLowerCase()}.${lastName.toLowerCase()}+${index}@example.com`,
    joinedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function createDummyProfiles() {
  console.log('🧪 Creating UK dummy profiles...');

  const profiles = [];
  const createdIds = [];

  for (let i = 0; i < 20; i += 1) {
    const gender = i % 2 === 0 ? 'female' : 'male';
    const profile = buildProfile(i, gender);
    const docRef = await db.collection('users').add(profile);
    createdIds.push(docRef.id);
    profiles.push({ uid: docRef.id, gender, name: profile.displayName });
    console.log(`✅ ${i + 1}. ${profile.displayName} (${gender}) -> ${docRef.id}`);
  }

  // Create/overwrite a daily profiles doc for a known test user.
  const targetUserId = createdIds[0];
  const oppositeGenderProfiles = profiles.filter((p) => p.gender !== (profiles[0].gender));
  const dailyProfiles = oppositeGenderProfiles.slice(0, 5).map((profile, index) => ({
    profileId: profile.uid,
    compatibilityScore: 90 - index,
    matchReason: 'Dummy UK test profile',
  }));

  await db.collection('dailyProfiles').doc(today).collection('users').doc(targetUserId).set({
    uid: targetUserId,
    date: today,
    profiles: dailyProfiles,
    totalAvailable: dailyProfiles.length,
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`📅 Seeded dailyProfiles/${today}/users/${targetUserId} with ${dailyProfiles.length} profiles`);

  // Create/update the UK market doc so the router moves into active mode.
  await db.collection('markets').doc('uk').set({
    country: 'United Kingdom',
    phase: 'active',
    launchDate: admin.firestore.Timestamp.fromDate(new Date()),
    approvedProfileCount: 20,
    gender: {
      male: 10,
      female: 10,
    },
    dailyNotificationTime: '09:00',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log('🗂️ Updated markets/uk -> phase: active');

  // Create a simple test user doc if missing for the first seeded user.
  await db.collection('users').doc(targetUserId).update({
    countryOfResidence: 'United Kingdom',
    joinedWaitlistAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)),
    isAdmin: false,
    verificationStatus: 'verified',
    lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
    dailyProfilesLastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log('✅ Finished creating and seeding UK dummy profiles');
  console.log(`   - Total profiles created: ${createdIds.length}`);
  console.log(`   - Test user id: ${targetUserId}`);
  console.log(`   - Market doc: markets/uk`);
}

createDummyProfiles()
  .catch((error) => {
    console.error('❌ Failed to create dummy profiles:', error);
    process.exit(1);
  })
  .finally(() => process.exit(0));
