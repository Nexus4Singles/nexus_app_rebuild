const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function investigateTransactionGap() {
  const userId = 'NkQa8IaOTlXgqTQGaukysv2q0jk2';
  
  console.log(`\n=== INVESTIGATING ANDROID TRANSACTION GAP ===`);
  console.log(`User ID: ${userId}\n`);
  
  // 1. Check user exists
  console.log('--- USER PROFILE ---');
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    console.log('❌ User does not exist in Firestore');
    return;
  }
  console.log('✓ User exists');
  const userData = userDoc.data();
  console.log(`Email: ${userData.email}`);
  console.log(`Device: ${userData.device || 'unknown'}`);
  
  // 2. Check subscription record
  console.log('\n--- FIRESTORE SUBSCRIPTION RECORD ---');
  const subDoc = await db.collection('users').doc(userId).collection('subscription').doc('current').get();
  if (!subDoc.exists) {
    console.log('❌ NO subscription/current document in Firestore');
  } else {
    console.log('✓ Subscription record exists:');
    const subData = subDoc.data();
    console.log(JSON.stringify(subData, null, 2));
  }
  
  // 3. Check for optimistic record field
  console.log('\n--- OPTIMISTIC RECORD CHECK ---');
  const userSubDoc = userDoc.data().subscription;
  if (!userSubDoc) {
    console.log('❌ No subscription field on user doc');
  } else {
    if (userSubDoc.optimisticRecord) {
      console.log('⚠️  Optimistic record exists: true');
      console.log(`verificationStatus: ${userSubDoc.verificationStatus}`);
    } else {
      console.log('❌ No optimistic record on user doc');
    }
  }
  
  // 4. Check audit logs (limit to avoid index requirements)
  console.log('\n--- AUDIT LOGS (all) ---');
  try {
    const auditSnap = await db.collection('users').doc(userId).collection('audit_log')
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();
    
    if (auditSnap.empty) {
      console.log('❌ No audit logs at all');
    } else {
      console.log(`✓ Found ${auditSnap.size} audit log entries total:`);
      auditSnap.forEach(doc => {
        const log = doc.data();
        console.log(`  - ${log.action} (${log.timestamp?.toDate?.() || log.timestamp})`);
      });
    }
  } catch (err) {
    console.log('⚠️  Could not query audit logs:', err.message);
  }
  
  // 5. Check transaction records
  console.log('\n--- TRANSACTION RECORDS ---');
  const txSnap = await db.collection('users').doc(userId).collection('transactions').get();
  if (txSnap.empty) {
    console.log('❌ No transaction records in Firestore');
  } else {
    console.log(`✓ Found ${txSnap.size} transaction(s):`);
    txSnap.forEach(doc => {
      console.log(`  - ${doc.id}: ${JSON.stringify(doc.data(), null, 2)}`);
    });
  }
  
  // 6. Compare to previous Android issue (tosgirl4christ@gmail.com)
  console.log('\n--- COMPARISON TO PREVIOUS ANDROID ISSUE ---');
  const previousUserId = 'LB6dH1NJBQgb7qCGk3NnJqOiHvP2'; // Searching for tosgirl4christ email
  
  // Actually let me search for the user by email
  const previousUserSnap = await db.collection('users')
    .where('email', '==', 'tosgirl4christ@gmail.com')
    .limit(1)
    .get();
  
  if (previousUserSnap.empty) {
    console.log('Could not find previous Android user by email');
  } else {
    const prevDoc = previousUserSnap.docs[0];
    const prevId = prevDoc.id;
    const prevSubDoc = await db.collection('users').doc(prevId).collection('subscription').doc('current').get();
    
    console.log(`Previous user (${prevId}):`);
    console.log(`  - Has subscription record: ${prevSubDoc.exists}`);
    
    if (prevSubDoc.exists) {
      const prevSubData = prevSubDoc.data();
      console.log(`  - Tier: ${prevSubData.tier}`);
      console.log(`  - IsActive: ${prevSubData.isActive}`);
      console.log(`  - Verification Status: ${prevSubData.verificationStatus}`);
    }
  }
  
  // 7. Analysis
  console.log('\n--- ANALYSIS ---');
  console.log(`Current User (${userId}):`);
  console.log(`  - Has subscription in Firestore: ${subDoc.exists ? '✓' : '❌'}`);
  console.log(`  - Has optimistic record: ${userSubDoc?.optimisticRecord ? '✓' : '❌'}`);
  console.log(`  - Has transaction records: ${txSnap.empty ? '❌' : '✓'}`);
  
  // Summary
  console.log('\n--- CRITICAL FINDING ---');
  if (!subDoc.exists && !userSubDoc?.optimisticRecord && txSnap.empty) {
    console.log('⚠️  BLOCKCHAIN STATE: No trace of subscription attempt in Firestore');
    console.log('This means RevenueCat webhook processing never reached our backend');
  }
}

investigateTransactionGap().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
