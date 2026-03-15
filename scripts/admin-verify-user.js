#!/usr/bin/env node

/**
 * ADMIN VERIFICATION SCRIPT
 * 
 * Manually verify a user's dating profile using Firebase Admin SDK
 * 
 * USAGE:
 *   node admin-verify-user.js <email> [status]
 * 
 * EXAMPLES:
 *   node admin-verify-user.js arc.prosperchukwuka@gmail.com
 *   node admin-verify-user.js user@example.com verified
 *   node admin-verify-user.js user@example.com rejected
 * 
 * REQUIREMENTS:
 *   - serviceAccount.json in project root
 *   - Firebase Admin SDK installed
 */

const admin = require('firebase-admin');
const path = require('path');

// Get email and status from command line args
const email = process.argv[2];
const status = (process.argv[3] || 'verified').toLowerCase();

if (!email) {
  console.error('❌ Usage: node admin-verify-user.js <email> [status]');
  console.error('   status can be: verified, rejected, pending (defaults to verified)');
  process.exit(1);
}

// Validate status
if (!['verified', 'rejected', 'pending'].includes(status)) {
  console.error(`❌ Invalid status: ${status}. Must be: verified, rejected, or pending`);
  process.exit(1);
}

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '../serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function verifyUser() {
  console.log('\n' + '='.repeat(70));
  console.log(`🔐 ADMIN USER VERIFICATION`);
  console.log('='.repeat(70) + '\n');

  const normalizedEmail = email.trim().toLowerCase();
  
  try {
    // Step 1: Find user
    console.log(`📧 Step 1: Finding user with email: ${normalizedEmail}`);
    
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('email', '==', normalizedEmail)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.error(`❌ User not found with email: ${normalizedEmail}\n`);
      process.exit(1);
    }

    const userDoc = usersSnapshot.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();

    console.log(`✅ User found!`);
    console.log(`   UID: ${userId}`);
    console.log(`   Email: ${userData.email}`);
    console.log(`   Username: ${userData.username || 'N/A'}`);
    console.log(`   Name: ${userData.name || 'N/A'}`);

    // Check current status
    const currentDating = userData.dating || {};
    const currentStatus = currentDating.verificationStatus || 'unset';
    console.log(`   Current verification status: ${currentStatus}\n`);

    // Step 2: Update verification
    console.log(`⏳ Step 2: Updating verification status to '${status}'...`);

    const updateData = {
      'dating.verificationStatus': status,
      'dating.verifiedAt': admin.firestore.FieldValue.serverTimestamp(),
      'dating.verifiedBy': 'admin_cli_script',
      'dating.reviewedAt': admin.firestore.FieldValue.serverTimestamp(),
      'dating.reviewedBy': 'admin_cli_script',
    };

    // Add rejection reason if rejecting
    if (status === 'rejected') {
      updateData['dating.rejectionReason'] = 'Admin manual rejection - reason not provided';
    }

    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update(updateData);

    // Log to audit trail
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('auditLog')
      .add({
        action: 'dating_profile_verified_via_admin_cli',
        status,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log(`✅ Verification updated!\n`);

    // Step 3: Verify & display updated data
    console.log(`📝 Updated verification fields:`);
    const updatedDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    const updatedDating = updatedDoc.data()?.dating || {};
    console.log(`   verificationStatus: ${updatedDating.verificationStatus}`);
    console.log(`   verifiedBy: ${updatedDating.verifiedBy}`);
    console.log(`   verifiedAt: ${updatedDating.verifiedAt?.toDate().toISOString() || 'N/A'}`);

    console.log('\n' + '='.repeat(70));
    console.log(`✅ SUCCESS! User verified with status: ${status}`);
    console.log('='.repeat(70) + '\n');

    process.exit(0);

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.error(error);
    process.exit(1);
  }
}

verifyUser();
