const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccount.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

async function findUserByAnonymousId(anonymousId) {
  try {
    console.log(`🔍 Searching for user with RevenueCat anonymous ID: ${anonymousId}\n`);

    // Try searching in subscription data
    console.log('📋 Searching for matching subscription records...');
    
    // Search across all users
    const usersSnapshot = await db.collection('users').get();
    
    let found = [];
    let checked = 0;

    for (const userDoc of usersSnapshot.docs) {
      checked++;
      const userData = userDoc.data();
      
      // Check various fields that might contain RevenueCat identifiers
      const subscription = userData.subscription || {};
      const revenueCatCustomerId = userData.revenueCatCustomerId || '';
      const email = userData.email || '';
      
      // Log every 100 users to show progress
      if (checked % 100 === 0) {
        console.log(`   Checked ${checked} users...`);
      }
      
      // Check if any field contains the anonymous ID
      const userJson = JSON.stringify(userData);
      if (userJson.includes(anonymousId) || userJson.includes('80acca065a49401399e6918ba7ca8824')) {
        found.push({
          uid: userDoc.id,
          name: userData.name,
          email: userData.email,
          subscriptionTxId: subscription.revenueCatTransactionId,
          subscriptionActive: subscription.isActive,
        });
      }
    }

    console.log(`\n✅ Checked ${checked} users total\n`);

    if (found.length > 0) {
      console.log(`🎯 Found ${found.length} user(s) with this anonymous ID:`);
      found.forEach((user, idx) => {
        console.log(`\n${idx + 1}. User: ${user.name}`);
        console.log(`   UID: ${user.uid}`);
        console.log(`   Email: ${user.email}`);
        console.log(`   Subscription Active: ${user.subscriptionActive}`);
        console.log(`   Transaction ID: ${user.subscriptionTxId}`);
      });
    } else {
      console.log('❌ No users found with this anonymous ID');
      console.log('\n💡 Alternative suggestions:');
      console.log('   1. Check RevenueCat dashboard for webhook events with this ID');
      console.log('   2. Look for Firebase Auth users with similar signup time');
      console.log('   3. Search app logs for this ID pattern');
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

const anonymousId = process.argv[2];

if (!anonymousId) {
  console.log('Usage: node scripts/find_user_by_revenuecat_id.js <anonymousId>');
  console.log('Example: node scripts/find_user_by_revenuecat_id.js $RCAnonymousID:80acca065a49401399e6918ba7ca8824');
  process.exit(1);
}

findUserByAnonymousId(anonymousId).then(() => process.exit(0));
