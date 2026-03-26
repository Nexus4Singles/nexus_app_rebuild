#!/usr/bin/env node

/**
 * RESTORE ARCHIVED DATING PROFILE
 * 
 * Restores a user's dating profile that was archived (mistakenly or otherwise).
 * This reactivates their profile without losing any dating data.
 * 
 * USAGE:
 *   node restore_archived_profile.js <userID|email>
 * 
 * EXAMPLE:
 *   node restore_archived_profile.js joashekele.d@gmail.com
 *   node restore_archived_profile.js vesZztygrfQ2PhPlfig9SabyY1t1
 * 
 * REQUIREMENTS:
 *   - serviceAccount.json in project root
 *   - Firebase Admin SDK installed
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function restoreArchivedProfile(userIdOrEmail) {
  try {
    const db = admin.firestore();
    let userId, userDoc, userData;

    // Determine if input is email or userId
    const isEmail = userIdOrEmail.includes('@');

    if (isEmail) {
      console.log(`\n🔍 Looking up user by email: ${userIdOrEmail}`);
      const usersSnapshot = await db
        .collection('users')
        .where('email', '==', userIdOrEmail)
        .limit(1)
        .get();

      if (usersSnapshot.empty) {
        console.log(`❌ No user found with email: ${userIdOrEmail}\n`);
        process.exit(1);
      }

      userDoc = usersSnapshot.docs[0];
      userId = userDoc.id;
      userData = userDoc.data();
    } else {
      console.log(`\n🔍 Looking up user by ID: ${userIdOrEmail}`);
      userDoc = await db.collection('users').doc(userIdOrEmail).get();

      if (!userDoc.exists) {
        console.log(`❌ No user found with ID: ${userIdOrEmail}\n`);
        process.exit(1);
      }

      userId = userIdOrEmail;
      userData = userDoc.data();
    }

    console.log(`✅ Found user: ${userId}`);
    console.log(`   Username: ${userData.username || userData.name}`);
    console.log(`   Email: ${userData.email}`);

    // Check current dating profile status
    const dating = userData.dating || {};
    console.log(`\n📋 Current Dating Profile Status:`);
    console.log(`   profileCompleted: ${dating.profileCompleted}`);
    console.log(`   isActive: ${dating.isActive}`);
    console.log(`   optIn: ${dating.optIn}`);
    console.log(`   archivedAt: ${dating.archivedAt?.toDate?.() || dating.archivedAt || 'NOT SET'}`);
    console.log(`   Has photos: ${dating.photos ? dating.photos.length : 0}`);
    console.log(`   Has audio: ${dating.audio ? dating.audio.length : 0}`);

    // Check if profile is actually archived
    if (dating.isActive !== false) {
      console.log(`\n⚠️  Profile is not archived (isActive is not false). No restoration needed.\n`);
      process.exit(0);
    }

    console.log(`\n🔄 Restoring profile...`);

    // Reactivate profile
    const updateData = {
      'dating.profileCompleted': true,
      'dating.isActive': true,
      'dating.optIn': true,
      'dating.restoredAt': admin.firestore.FieldValue.serverTimestamp(),
    };

    // Remove archivedAt field
    updateData['dating.archivedAt'] = admin.firestore.FieldValue.delete();

    await db.collection('users').doc(userId).update(updateData);

    console.log(`✅ Profile successfully restored!\n`);
    console.log(`   Profile will now appear in dating search results`);
    console.log(`   User can see their profile in the app immediately\n`);

  } catch (error) {
    console.error(`\n❌ Error: ${error.message}\n`);
    process.exit(1);
  }
}

// Get email from command line argument
const userIdOrEmail = process.argv[2];

if (!userIdOrEmail) {
  console.error(`
Usage: node restore_archived_profile.js <userID|email>

Arguments:
  <userID|email>  User ID or email address

Examples:
  node restore_archived_profile.js joashekele.d@gmail.com
  node restore_archived_profile.js vesZztygrfQ2PhPlfig9SabyY1t1
  `);
  process.exit(1);
}

restoreArchivedProfile(userIdOrEmail);
