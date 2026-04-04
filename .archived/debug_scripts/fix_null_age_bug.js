#!/usr/bin/env node

/**
 * FIX NULL AGE BUG
 * 
 * ROOT CAUSE ANALYSIS:
 * 1. DatingAgeScreen initializes with selectedAge=21 but draft.age can be null
 * 2. If user's previous draft had null age and they resume onboarding, 
 *    the null persists without being properly overridden
 * 3. When profile is finalized, the null gets saved to Firestore
 * 4. App's profile completion check reads from separate datingProfiles collection
 *    which is never populated, causing profile to show as incomplete
 *
 * BUG IMPACT:
 * - User sees "?" where age should be
 * - User cannot access dating search/chat features
 * - Profile stuck in incomplete state
 *
 * FIX STRATEGY:
 * 1. Set dating.profile.age to a valid value
 * 2. Create datingProfiles/{uid} document with essential fields
 * 3. Sync back to root age field for backward compatibility
 *
 * NOTE: Since age was saved as null and no audit trail shows what user entered,
 * we use reasonable minimum (21 years - app's minimum age) as placeholder.
 * This allows user to manually update their age profile afterward.
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function fixNullAgeBug(email, overrideAge = null) {
  try {
    const db = admin.firestore();
    
    // Step 1: Get user
    const snapshot = await db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (snapshot.empty) {
      console.log('❌ User not found');
      process.exit(1);
    }

    const userDoc = snapshot.docs[0];
    const uid = userDoc.id;
    const userData = userDoc.data();

    console.log(`\n📋 TARGET USER:`);
    console.log(`   UID: ${uid}`);
    console.log(`   Email: ${email}`);
    console.log(`   Name: ${userData.dating?.profile?.name}`);
    console.log(`   Current age: ${userData.dating?.profile?.age}`);
    
    // Determine age to use
    const ageToSet = overrideAge || 21; // Default to minimum allowed age
    console.log(`\n🔧 APPLYING FIX:`);
    console.log(`   Setting age to: ${ageToSet}`);
    
    // Step 2: Update users/{uid} with valid age
    console.log(`\n   1️⃣ Updating users/${uid}...`);
    await db.collection('users').doc(uid).update({
      'age': ageToSet,
      'dating.profile.age': ageToSet,
    });
    console.log(`      ✅ Set age=${ageToSet} in users collection`);

    // Step 3: Create/update datingProfiles/{uid} document
    console.log(`\n   2️⃣ Creating datingProfiles/${uid}...`);
    
    const datingProfile = userData.dating?.profile || {};
    const datingProfilesData = {
      name: datingProfile.name || userData.username || userData.dating?.profile?.name || 'User',
      age: ageToSet,
      gender: datingProfile.gender || userData.dating?.gender,
      photos: Array.isArray(datingProfile.photos) && datingProfile.photos.length > 0 
        ? datingProfile.photos 
        : [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('datingProfiles').doc(uid).set(datingProfilesData, { merge: true });
    console.log(`      ✅ Created/updated datingProfiles/${uid}`);
    console.log(`         name: ${datingProfilesData.name}`);
    console.log(`         age: ${datingProfilesData.age}`);
    console.log(`         gender: ${datingProfilesData.gender}`);
    console.log(`         photos: ${Array.isArray(datingProfilesData.photos) ? datingProfilesData.photos.length : 0}`);

    // Step 4: Verify fix
    console.log(`\n   3️⃣ Verifying fix...`);
    const updatedUserDoc = await db.collection('users').doc(uid).get();
    const updatedUserData = updatedUserDoc.data();
    const updatedDatingProfileDoc = await db.collection('datingProfiles').doc(uid).get();

    const verifyAge = updatedUserData.dating?.profile?.age;
    const datingProfilesExists = updatedDatingProfileDoc.exists;
    const datingProfilesAge = updatedDatingProfileDoc.data()?.age;

    if (verifyAge === ageToSet && datingProfilesExists && datingProfilesAge === ageToSet) {
      console.log(`      ✅ FIX VERIFIED:`);
      console.log(`         • users/{uid}.dating.profile.age = ${verifyAge}`);
      console.log(`         • datingProfiles/{uid} exists = YES`);
      console.log(`         • datingProfiles/{uid}.age = ${datingProfilesAge}`);
    } else {
      console.log(`      ⚠️ VERIFICATION FAILED`);
      console.log(`         • users age: ${verifyAge}`);
      console.log(`         • datingProfiles exists: ${datingProfilesExists}`);
    }

    console.log(`\n✅ FIX COMPLETE`);
    console.log(`\nℹ️ User can now:`);
    console.log(`   • See their age (${ageToSet}) on their profile`);
    console.log(`   • Access dating search and chat features`);
    console.log(`   • Update their age in profile settings if needed`);
    console.log(`\n💡 RECOMMENDED:`);
    console.log(`   • Notify user that age was set to ${ageToSet} due to app bug`);
    console.log(`   • Make sure they update it to their actual age`);

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

const email = process.argv[2];
const overrideAge = process.argv[3] ? parseInt(process.argv[3]) : null;

if (!email) {
  console.log('USAGE: node fix_null_age_bug.js <email> [<age>]');
  console.log('\nEXAMPLES:');
  console.log('  node fix_null_age_bug.js khadilawal8@gmail.com');
  console.log('  node fix_null_age_bug.js khadilawal8@gmail.com 25');
  process.exit(1);
}

fixNullAgeBug(email, overrideAge);
