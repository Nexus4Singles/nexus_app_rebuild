#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function investigateVerificationStatus() {
  const db = admin.firestore();
  const userId = '0ELDp8QMw4S9fAvhFmwByWQ1E9p1';
  
  console.log('\n═══════════════════════════════════════════════════════════');
  console.log('INVESTIGATING VERIFICATION STATUS REGRESSION');
  console.log(`User ID: ${userId}`);
  console.log('═══════════════════════════════════════════════════════════\n');
  
  // Get user document
  const userDoc = await db.collection('users').doc(userId).get();
  
  if (!userDoc.exists) {
    console.log('❌ User not found');
    process.exit(1);
  }
  
  const userData = userDoc.data();
  
  console.log('SECTION 1: Current Subscription State\n');
  console.log('Subscription field:');
  console.log(JSON.stringify(userData.subscription, null, 2));
  
  console.log('\nCurrent verificationStatus:');
  console.log(`  ${userData.subscription?.verificationStatus || 'NOT SET'}`);
  
  console.log('\n───────────────────────────────────────────────────────────');
  console.log('SECTION 2: Audit Log History\n');
  
  const auditRef = userDoc.ref.collection('auditLog');
  const auditSnapshot = await auditRef.orderBy('timestamp', 'desc').limit(20).get();
  
  if (auditSnapshot.empty) {
    console.log('❌ NO audit logs found');
  } else {
    console.log(`Found ${auditSnapshot.size} audit log entries:\n`);
    
    let subscriptionRelatedLogs = [];
    
    auditSnapshot.forEach((doc, idx) => {
      const log = doc.data();
      const action = log.action || 'unknown';
      const timestamp = log.timestamp?.toDate?.()?.toISOString() || log.timestamp;
      
      // Look for subscription-related actions
      if (action.includes('subscription') || action.includes('verification')) {
        console.log(`[${idx + 1}] ${action}`);
        console.log(`    Timestamp: ${timestamp}`);
        console.log(`    Status: ${log.verificationStatus || 'N/A'}`);
        console.log(`    Provider: ${log.provider || 'N/A'}`);
        console.log(`    Tier: ${log.tier || 'N/A'}`);
        console.log('');
        subscriptionRelatedLogs.push(log);
      }
    });
    
    if (subscriptionRelatedLogs.length === 0) {
      console.log('No subscription-related audit logs found. Showing all recent actions:\n');
      auditSnapshot.forEach((doc, idx) => {
        const log = doc.data();
        console.log(`[${idx + 1}] ${log.action || 'unknown'}`);
        console.log(`    Time: ${log.timestamp?.toDate?.()?.toISOString()}`);
        console.log('');
      });
    }
  }
  
  console.log('───────────────────────────────────────────────────────────');
  console.log('SECTION 3: Transaction History\n');
  
  const transRef = userDoc.ref.collection('transactions');
  const transSnapshot = await transRef.orderBy('transactionDate', 'desc').limit(10).get();
  
  if (transSnapshot.empty) {
    console.log('❌ NO transactions found');
  } else {
    console.log(`Found ${transSnapshot.size} transaction(s):\n`);
    transSnapshot.forEach((doc, idx) => {
      const tx = doc.data();
      console.log(`[${idx + 1}] Transaction: ${doc.id}`);
      console.log(`    Date: ${tx.transactionDate?.toDate?.()?.toISOString() || tx.timestamp?.toDate?.()?.toISOString()}`);
      console.log(`    Status: ${tx.status || tx.verificationStatus || 'unknown'}`);
      console.log(`    Amount: ${tx.amount}`);
      console.log('');
    });
  }
  
  console.log('───────────────────────────────────────────────────────────');
  console.log('SECTION 4: ROOT CAUSE ANALYSIS\n');
  
  // Determine what caused the regression
  const subscription = userData.subscription || {};
  const optimisticRecord = subscription.optimisticRecord;
  const verificationStatus = subscription.verificationStatus;
  const isActive = subscription.isActive;
  const validatedBy = subscription.validatedBy;
  const validatedAt = subscription.validatedAt?.toDate?.()?.toISOString();
  
  console.log('Key indicators:');
  console.log(`  isActive: ${isActive}`);
  console.log(`  verificationStatus: ${verificationStatus}`);
  console.log(`  validatedBy: ${validatedBy}`);
  console.log(`  validatedAt: ${validatedAt}`);
  console.log(`  optimisticRecord: ${optimisticRecord}`);
  
  console.log('\n🔴 ROOT CAUSE ANALYSIS:\n');
  
  if (verificationStatus === 'pending' && isActive === true) {
    if (optimisticRecord === true) {
      console.log('ROOT CAUSE: Optimistic record not yet verified by backend');
      console.log('\nWhat happened:');
      console.log('1. User completed purchase through RevenueCat');
      console.log('2. App created optimistic subscription record immediately');
      console.log('3. verificationStatus was set to "pending" (awaiting backend validation)');
      console.log('4. Backend webhook should have updated verificationStatus to "verified"');
      console.log('   but this has NOT happened yet\n');
      console.log('Fix: Wait for RevenueCat webhook to fire, OR manually update verificationStatus');
    } else if (validatedBy === 'manual_activation') {
      console.log('ROOT CAUSE: Manual activation script used old version of code');
      console.log('\nWhat happened:');
      console.log('1. User was manually activated');
      console.log('2. The activation script set verificationStatus to old value/default');
      console.log('3. Should have been set to "verified" but shows "pending"\n');
      console.log('Likely cause: activate_user_subscription.js might need to be updated');
    } else if (validatedBy && validatedBy.includes('webhook')) {
      console.log('ROOT CAUSE: Subscription updated by webhook with pending status');
      console.log('\nWhat happened:');
      console.log('1. RevenueCat webhook triggered');
      console.log('2. Updated subscription but verificationStatus was set/kept as "pending"');
      console.log('3. This should not happen - webhook should set "verified"\n');
      console.log('Check: RevenueCat webhook handler might have a bug');
    } else {
      console.log('ROOT CAUSE: Unknown - verificationStatus was set to "pending" for unclear reason');
      console.log('\nDetails:');
      console.log(`  - isActive: ${isActive} (subscription IS active - good)`);
      console.log(`  - verificationStatus: ${verificationStatus} (should be "verified")`);
      console.log(`  - validatedBy: ${validatedBy}`);
      console.log(`  - validatedAt: ${validatedAt}`);
    }
  } else if (verificationStatus !== 'pending') {
    console.log('✅ verificationStatus is already correct: ' + verificationStatus);
  } else if (!isActive) {
    console.log('⚠️  Subscription is NOT active (isActive=false)');
    console.log('   verificationStatus being "pending" is expected for inactive subscriptions');
  }
  
  process.exit(0);
}

investigateVerificationStatus().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
