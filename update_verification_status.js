#!/usr/bin/env node

/**
 * Update a user's verification status
 * Usage: node update_verification_status.js <email> <newStatus>
 *   e.g., node update_verification_status.js contact@nexus4singles.com unverified
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function updateVerificationStatus(email, newStatus) {
  if (!email || !newStatus) {
    console.error('Usage: node update_verification_status.js <email> <newStatus>');
    console.error('Example: node update_verification_status.js contact@nexus4singles.com unverified');
    process.exit(1);
  }

  try {
    console.log(`\n🔍 Finding user with email: ${email}`);
    
    // Search for user by email
    const snapshot = await db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (snapshot.empty) {
      console.error(`❌ User not found with email: ${email}`);
      process.exit(1);
    }

    const userDoc = snapshot.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();

    console.log(`✅ Found user: ${userId}`);
    console.log(`   Name: ${userData.name || userData.username || 'N/A'}`);
    console.log(`   Current status: ${userData.dating?.verificationStatus || 'N/A'}`);
    console.log(`   New status: ${newStatus}`);

    // Update verification status
    await db.collection('users').doc(userId).update({
      'dating.verificationStatus': newStatus,
      'dating.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`\n✅ SUCCESS: Updated ${userData.email} verification status to "${newStatus}"`);
    console.log(`   Firestore path: users/${userId}/dating.verificationStatus`);
    
  } catch (error) {
    console.error(`\n❌ Error:`, error.message);
    process.exit(1);
  } finally {
    admin.app().delete();
  }
}

const email = process.argv[2];
const newStatus = process.argv[3];
updateVerificationStatus(email, newStatus);
