const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function verifyUser() {
  const email = 'contact@nexus4singles.com';
  
  console.log(`\n=== VERIFYING USER FOR PROFILE SEARCH ===\n`);
  console.log(`Email: ${email}\n`);

  try {
    // 1. Find user by email
    console.log('🔍 Finding user...');
    const usersSnapshot = await db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.error(`❌ User not found`);
      process.exit(1);
    }

    const userDoc = usersSnapshot.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();
    
    console.log(`✓ User found: ${userId}`);
    console.log(`  Name: ${userData.username || userData.name}`);
    console.log(`  Email: ${userData.email}\n`);

    // 2. Check current verification status
    console.log('📋 Current Status:');
    console.log(`  - emailVerified: ${userData.emailVerified}`);
    console.log(`  - userVerified: ${userData.userVerified}`);
    console.log(`  - verificationStatus: ${userData.verificationStatus || 'not set'}\n`);

    // 3. Update verification fields
    console.log('✅ Updating verification status...\n');
    
    const updateData = {
      emailVerified: true,
      userVerified: true,
      verificationStatus: 'verified',
      verifiedAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
    };

    await userDoc.ref.update(updateData);

    // 4. Create audit log
    await userDoc.ref.collection('audit_log').add({
      action: 'user_verified',
      reason: 'manual_verification_for_profile_search',
      verifiedBy: 'admin_script',
      timestamp: admin.firestore.Timestamp.now(),
      details: {
        emailVerified: true,
        userVerified: true,
        canNowSearch: true
      }
    });

    // 5. Verify changes
    const updatedUserDoc = await userDoc.ref.get();
    const updatedData = updatedUserDoc.data();
    
    console.log('Updated Status:');
    console.log(`  - emailVerified: ${updatedData.emailVerified}`);
    console.log(`  - userVerified: ${updatedData.userVerified}`);
    console.log(`  - verificationStatus: ${updatedData.verificationStatus}\n`);

    console.log(`✅ USER VERIFIED`);
    console.log(`User ${email} can now search for profiles\n`);

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

verifyUser();
