const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function checkPurchaseRecords() {
  try {
    const userId = 'nnvfiqInGrZdXKuFmXGD03Qrsoas2';
    
    console.log('\n=== SEARCHING FOR USER ===\n');
    
    // Try to find by user ID directly
    console.log('1. Direct user document lookup:');
    const userDoc = await db.collection('users').doc(userId).get();
    console.log('   Found:', userDoc.exists ? '✅ YES' : '❌ NO');
    
    // Search in purchase records
    console.log('\n2. Search in purchase records:');
    const purchases = await db.collectionGroup('purchases')
      .where('revenueCatCustomerId', '==', userId)
      .limit(5)
      .get();
    console.log('   Found:', purchases.size > 0 ? `✅ ${purchases.size} record(s)` : '❌ NO');
    
    if (purchases.size > 0) {
      for (const doc of purchases.docs) {
        console.log('\n   Purchase Record:');
        console.log('   ', JSON.stringify(doc.data(), null, 4));
      }
    }
    
    // Search in notifications
    console.log('\n3. Search in subscription notifications:');
    const notifications = await db.collectionGroup('notifications')
      .where('type', '==', 'subscription_activated')
      .limit(10)
      .get();
    
    for (const doc of notifications.docs) {
      const data = doc.data();
      const path = doc.ref.path;
      const userIdFromPath = path.split('/')[1];
      
      if (userIdFromPath === userId) {
        console.log(`   ✅ Found subscription notification for this user: ${data.createdAt?.toDate()?.toISOString() || 'N/A'}`);
      }
    }
    
    // List all users to see if there's a similar ID
    console.log('\n4. Searching for similar user IDs (first 10 users):');
    const allUsers = await db.collection('users').limit(10).get();
    console.log(`   Total users found: ${allUsers.size}`);
    
    let hasPartialMatch = false;
    for (const doc of allUsers.docs) {
      const id = doc.id;
      if (id.includes(userId.substring(0, 8))) {
        console.log(`   - ${id}`);
        hasPartialMatch = true;
      }
    }
    
    if (!hasPartialMatch) {
      console.log('   No similar IDs found');
    }
    
  } catch (e) {
    console.error('Error:', e.message);
    process.exit(1);
  }
}

checkPurchaseRecords();
