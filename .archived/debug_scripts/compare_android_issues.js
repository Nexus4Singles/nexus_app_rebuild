const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function compareAndroidIssues() {
  console.log(`\n=== COMPARING ANDROID TRANSACTION ISSUES ===\n`);
  
  // Current issue
  const currentUserId = 'NkQa8IaOTlXgqTQGaukysv2q0jk2';
  
  // Previous issue - search by email
  const previousUserSnap = await db.collection('users')
    .where('email', '==', 'tosgirl4christ@gmail.com')
    .limit(1)
    .get();
  
  let previousUserId = null;
  if (!previousUserSnap.empty) {
    previousUserId = previousUserSnap.docs[0].id;
  }
  
  // Analyze current user
  console.log('--- CURRENT ISSUE (NkQa8IaOTlXgqTQGaukysv2q0jk2) ---');
  const currentUserDoc = await db.collection('users').doc(currentUserId).get();
  const currentSubDoc = await db.collection('users').doc(currentUserId).collection('subscription').doc('current').get();
  const currentTxSnap = await db.collection('users').doc(currentUserId).collection('transactions').get();
  
  console.log(`Email: ${currentUserDoc.data().email}`);
  console.log(`Has subscription/current: ${currentSubDoc.exists ? 'YES' : 'NO'}`);
  console.log(`Has any transactions: ${currentTxSnap.empty ? 'NO' : 'YES'}`);
  console.log(`Subscription field on user doc: ${currentUserDoc.data().subscription ? 'YES' : 'NO'}`);
  if (currentUserDoc.data().subscription) {
    console.log(`  - optimisticRecord: ${currentUserDoc.data().subscription.optimisticRecord}`);
  }
  
  let prevSubDoc = null;
  if (previousUserId) {
    console.log(`\n--- PREVIOUS ISSUE (tosgirl4christ@gmail.com / ${previousUserId}) ---`);
    const prevUserDoc = await db.collection('users').doc(previousUserId).get();
    prevSubDoc = await db.collection('users').doc(previousUserId).collection('subscription').doc('current').get();
    const prevTxSnap = await db.collection('users').doc(previousUserId).collection('transactions').get();
    
    console.log(`Email: ${prevUserDoc.data().email}`);
    console.log(`Has subscription/current: ${prevSubDoc.exists ? 'YES' : 'NO'}`);
    if (prevSubDoc.exists) {
      const subData = prevSubDoc.data();
      console.log(`  - Tier: ${subData.tier}`);
      console.log(`  - isActive: ${subData.isActive}`);
      console.log(`  - Expiry: ${subData.expiryDate?.toDate?.() || 'N/A'}`);
      console.log(`  - verificationStatus: ${subData.verificationStatus}`);
    }
    console.log(`Has any transactions: ${prevTxSnap.empty ? 'NO' : 'YES'}`);
    console.log(`Subscription field on user doc: ${prevUserDoc.data().subscription ? 'YES' : 'NO'}`);
    if (prevUserDoc.data().subscription) {
      console.log('  - Subscription field contents:');
      console.log(`    ${JSON.stringify(prevUserDoc.data().subscription, null, 2)}`);
    }
  } else {
    console.log('\n⚠️  Could not find previous user (tosgirl4christ@gmail.com)');
  }
  
  // Pattern analysis
  console.log(`\n--- PATTERN ANALYSIS ---`);
  console.log('Current user pattern: No subscription record + No optimistic record + No transactions');
  if (previousUserId) {
    console.log(`Previous user pattern: ${prevSubDoc.exists ? 'Has subscription/current record' : 'No subscription/current record'} + Has subscription field on user doc`);
  }
}

compareAndroidIssues().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
