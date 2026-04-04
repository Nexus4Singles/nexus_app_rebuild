#!/usr/bin/env node

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function checkAndVerifyUser(email) {
  try {
    const db = admin.firestore();
    
    console.log(`\n🔍 Looking up user: ${email}`);
    
    // Find user by email
    const usersSnapshot = await db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.log(`❌ No user found with email: ${email}\n`);
      process.exit(1);
    }

    const userDoc = usersSnapshot.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();

    console.log(`✅ Found user: ${userId}`);
    console.log(`   Name: ${userData.username || userData.name}`);
    console.log(`   Email: ${userData.email}`);

    // Check current verification status
    const dating = userData['dating'] || {};
    console.log(`\n📋 Current Dating Profile Status:`);
    console.log(`   Verification Status: ${dating.verificationStatus || 'NOT SET'}`);
    console.log(`   Verified At: ${dating.verifiedAt ? new Date(dating.verifiedAt.toDate()).toLocaleString() : 'N/A'}`);
    console.log(`   Verified By: ${dating.verifiedBy || 'N/A'}`);
    console.log(`   Reviewed At: ${dating.reviewedAt ? new Date(dating.reviewedAt.toDate()).toLocaleString() : 'N/A'}`);
    console.log(`   Review Quality: ${dating.reviewQuality || 'N/A'}`);
    console.log(`   Rejection Reason: ${dating.rejectionReason || 'N/A'}`);

    // Check if user has dating profile at all
    if (Object.keys(dating).length === 0 || !dating.photoUrls) {
      console.log(`\n⚠️  WARNING: User has no dating profile data or photos!`);
      console.log(`   Dating Object Keys: ${Object.keys(dating).join(', ') || 'EMPTY'}`);
    }

    // Check if already verified
    if (dating.verificationStatus === 'verified') {
      console.log(`\n✅ User is already verified!`);
      console.log(`   Verified at: ${dating.verifiedAt ? new Date(dating.verifiedAt.toDate()).toLocaleString() : 'N/A'}`);
      process.exit(0);
    }

    // Update verification status
    console.log(`\n📝 Updating verification status to 'verified'...`);
    
    const now = admin.firestore.FieldValue.serverTimestamp();
    await db.collection('users').doc(userId).update({
      'dating.verificationStatus': 'verified',
      'dating.verifiedAt': now,
      'dating.verifiedBy': 'admin:manual_verification',
      'dating.reviewedAt': now,
      'dating.reviewedBy': 'admin',
    });

    console.log(`✅ Verification status updated to 'verified'!`);

    // Create notification
    await db
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .add({
        type: 'profile_verified',
        title: '✅ Profile Verified!',
        body: 'Congratulations! Your profile has been verified.',
        payload: {
          type: 'profile_verified',
          title: '✅ Profile Verified!',
          body: 'Congratulations! Your profile has been verified.',
          route: '/search',
        },
        createdAt: now,
        isSent: false,
      });

    console.log(`📬 Notification sent to user`);

    // Create audit log
    await db
      .collection('users')
      .doc(userId)
      .collection('auditLog')
      .add({
        action: 'dating_profile_verified_manually',
        performedBy: 'admin:manual',
        verificationStatus: 'verified',
        timestamp: now,
        reason: 'Manual re-verification by admin',
      });

    console.log(`📝 Audit log created\n`);

    process.exit(0);
  } catch (error) {
    console.error(`\n❌ Error: ${error.message}`);
    console.error(error);
    process.exit(1);
  }
}

// Get email from command line argument
const email = process.argv[2];

if (!email) {
  console.error(`
Usage: node check_and_verify_user.js <email>

Arguments:
  <email>  User email (e.g., arc.prosperchukwuka@gmail.com)

Example:
  node check_and_verify_user.js arc.prosperchukwuka@gmail.com
  `);
  process.exit(1);
}

checkAndVerifyUser(email);
