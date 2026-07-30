const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require(path.join(__dirname, '../serviceAccount.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-visibility-app.firebaseio.com'
});

const db = admin.firestore();

async function checkUserStatus(email) {
  try {
    console.log(`\n🔍 Checking status for user: ${email}\n`);
    
    // Query by email
    const snapshot = await db.collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();
    
    if (snapshot.empty) {
      console.log(`❌ User not found with email: ${email}`);
      process.exit(1);
    }
    
    const userDoc = snapshot.docs[0];
    const userData = userDoc.data();
    const uid = userDoc.id;
    
    console.log(`✅ User found: ${uid}\n`);
    console.log(`📋 User Details:`);
    console.log(`  - Email: ${userData.email}`);
    console.log(`  - Username: ${userData.username || userData.displayName || 'N/A'}`);
    
    // Check subscription status
    console.log(`\n💳 Subscription Status:`);
    if (userData.subscription && userData.subscription.isActive) {
      console.log(`  - Status: ACTIVE`);
      console.log(`  - Expiry Date: ${new Date(userData.subscription.expiryDate._seconds * 1000).toISOString().split('T')[0]}`);
      console.log(`  - Transaction ID: ${userData.subscription.revenueCatTransactionId || 'N/A'}`);
    } else {
      console.log(`  - Status: INACTIVE`);
    }
    
    // Check verification status
    console.log(`\n✔️ Verification Status:`);
    if (userData.dating && userData.dating.verificationStatus) {
      console.log(`  - Status: ${userData.dating.verificationStatus.toUpperCase()}`);
      console.log(`  - Verified By: ${userData.dating.verifiedBy || 'N/A'}`);
      console.log(`  - Verified At: ${userData.dating.verifiedAt ? new Date(userData.dating.verifiedAt._seconds * 1000).toISOString() : 'N/A'}`);
    } else {
      console.log(`  - Status: NOT VERIFIED`);
    }
    
    // Return user data for potential next steps
    return { uid, userData };
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

checkUserStatus(process.argv[2]).then(() => {
  process.exit(0);
});
