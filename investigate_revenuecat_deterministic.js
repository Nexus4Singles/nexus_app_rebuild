#!/usr/bin/env node

/**
 * DETERMINISTIC REVENUECAT WEBHOOK INVESTIGATION
 * Find users with actual purchases and check if subscriptions were created
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function investigateRevenueCat() {
  try {
    console.log('\n' + '='.repeat(80));
    console.log('DETERMINISTIC REVENUECAT WEBHOOK INVESTIGATION');
    console.log('='.repeat(80) + '\n');

    // ========================================================================
    // STEP 1: Find users with actual purchase records
    // ========================================================================
    console.log('STEP 1: Finding users with purchase/transaction records\n');

    let usersWithTransactions = [];
    let usersWithOptimisticRecords = [];

    // Check for users with subscription.packageId (optimistic client record)
    const allUsers = await db.collection('users').get();
    
    for (const userDoc of allUsers.docs) {
      const userData = userDoc.data();
      
      // Check for optimistic subscription records (created by app before server validation)
      if (userData.subscription && userData.subscription.packageId) {
        usersWithOptimisticRecords.push({
          uid: userDoc.id,
          email: userData.email,
          packageId: userData.subscription.packageId,
          subscriptionStatus: userData.subscription,
        });
      }

      // Check if user has transaction records
      const transactionsRef = userDoc.ref.collection('transactions');
      const transactionSnapshot = await transactionsRef.get();
      
      if (transactionSnapshot.size > 0) {
        usersWithTransactions.push({
          uid: userDoc.id,
          email: userData.email,
          transactionCount: transactionSnapshot.size,
          transactions: transactionSnapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
          })),
          subscription: userData.subscription,
        });
      }
    }

    console.log(`✓ Found ${usersWithTransactions.length} users with transaction records`);
    console.log(`✓ Found ${usersWithOptimisticRecords.length} users with optimistic subscription records\n`);

    // ========================================================================
    // STEP 2: Analyze transaction details
    // ========================================================================
    console.log('STEP 2: Analyzing transactions\n');

    let iosTransactions = 0;
    let androidTransactions = 0;
    let transactionsWithSubscription = 0;
    let transactionsWithoutSubscription = 0;

    console.log('Transaction Details:\n');

    for (const user of usersWithTransactions) {
      console.log(`User: ${user.email} (${user.uid})`);
      console.log(`  Transactions: ${user.transactionCount}`);

      user.transactions.forEach((tx, idx) => {
        const source = tx.source || tx.platform || 'unknown';
        const isIOS = source.toLowerCase().includes('ios') || source.toLowerCase().includes('app_store');
        const isAndroid = source.toLowerCase().includes('android') || source.toLowerCase().includes('play_store');
        
        if (isIOS) iosTransactions++;
        if (isAndroid) androidTransactions++;

        console.log(`    [${idx + 1}] ${source.toUpperCase()}`);
        console.log(`        Date: ${tx.transactionDate?.toDate?.()?.toISOString?.() || tx.timestamp?.toDate?.()?.toISOString?.() || 'N/A'}`);
        console.log(`        Status: ${tx.status || tx.verificationStatus || 'unknown'}`);
        
        if (user.subscription && user.subscription.isActive) {
          console.log(`        ✅ Associated subscription: EXISTS (tier: ${user.subscription.tier})`);
          transactionsWithSubscription++;
        } else {
          console.log(`        ❌ Associated subscription: MISSING`);
          transactionsWithoutSubscription++;
        }
      });
      console.log('');
    }

    // ========================================================================
    // STEP 3: Platform breakdown
    // ========================================================================
    console.log('-'.repeat(80));
    console.log('STEP 3: Platform Breakdown\n');

    console.log(`iOS transactions: ${iosTransactions}`);
    console.log(`Android transactions: ${androidTransactions}`);
    console.log(`Total transactions: ${iosTransactions + androidTransactions}\n`);

    // ========================================================================
    // STEP 4: Subscription conversion rate
    // ========================================================================
    console.log('-'.repeat(80));
    console.log('STEP 4: Subscription Conversion Rate\n');

    const totalTransactions = iosTransactions + androidTransactions;
    if (totalTransactions > 0) {
      const conversionRate = (transactionsWithSubscription / totalTransactions * 100).toFixed(1);
      console.log(`Transactions with subscriptions: ${transactionsWithSubscription}/${totalTransactions} (${conversionRate}%)`);
      console.log(`Transactions WITHOUT subscriptions: ${transactionsWithoutSubscription}/${totalTransactions}\n`);

      if (conversionRate < 100) {
        console.log('❌ NOT ALL TRANSACTIONS CONVERTED TO SUBSCRIPTIONS');
        console.log('   This indicates webhook is NOT firing for some transactions');
      }
    }

    // ========================================================================
    // STEP 5: Check RevenueCat webhook logs
    // ========================================================================
    console.log('-'.repeat(80));
    console.log('STEP 5: RevenueCat Webhook Logs\n');

    const rcWebhooks = await db.collection('revenuecat_webhooks').get();
    console.log(`RevenueCat webhook records in Firestore: ${rcWebhooks.size}`);

    if (rcWebhooks.size > 0) {
      console.log('\nRecent RevenueCat webhook events:\n');
      rcWebhooks.docs.slice(0, 10).forEach((doc, idx) => {
        const data = doc.data();
        console.log(`  [${idx + 1}] ${data.event || 'unknown'}`);
        console.log(`      Timestamp: ${data.timestamp?.toDate?.()?.toISOString?.() || 'N/A'}`);
        console.log(`      Status: ${data.status || 'recorded'}`);
      });
    } else {
      console.log('❌ NO REVENUECAT WEBHOOK LOGS FOUND');
    }

    // ========================================================================
    // STEP 6: Check subscription records creation patterns
    // ========================================================================
    console.log('\n' + '-'.repeat(80));
    console.log('STEP 6: Subscription Record Analysis\n');

    let subscriptionsBySource = {
      revenuecat_webhook: 0,
      manual_activation: 0,
      unknown: 0,
    };

    const allUsersSnapshot = await db.collection('users').get();
    for (const userDoc of allUsersSnapshot.docs) {
      const userData = userDoc.data();
      if (userData.subscription && userData.subscription.isActive) {
        const source = userData.subscription.validatedBy || 'unknown';
        if (source.includes('revenuecat')) {
          subscriptionsBySource.revenuecat_webhook++;
        } else if (source.includes('manual')) {
          subscriptionsBySource.manual_activation++;
        } else {
          subscriptionsBySource.unknown++;
        }
      }
    }

    console.log('Active subscriptions by source:');
    console.log(`  RevenueCat webhook: ${subscriptionsBySource.revenuecat_webhook}`);
    console.log(`  Manual activation: ${subscriptionsBySource.manual_activation}`);
    console.log(`  Unknown: ${subscriptionsBySource.unknown}\n`);

    // ========================================================================
    // SUMMARY & CONCLUSIONS
    // ========================================================================
    console.log('='.repeat(80));
    console.log('CONCLUSIONS\n');

    if (usersWithTransactions.length === 0) {
      console.log('❌ NO USERS WITH TRANSACTIONS FOUND');
      console.log('   Possible: Users haven\'t purchased yet, or transactions not stored');
    } else if (transactionsWithoutSubscription > 0) {
      const failureRate = (transactionsWithoutSubscription / totalTransactions * 100).toFixed(1);
      console.log(`❌ ${failureRate}% OF TRANSACTIONS FAILED TO CREATE SUBSCRIPTIONS`);
      console.log('   Webhook is either:');
      console.log('   1. Not being called by RevenueCat');
      console.log('   2. Being called but failing silently');
      console.log('   3. Only working for certain platforms (iOS vs Android)');
    } else if (subscriptionsBySource.revenuecat_webhook === 0 && usersWithTransactions.length > 0) {
      console.log('❌ NO SUBSCRIPTIONS CREATED VIA REVENUECAT WEBHOOK');
      console.log('   Transactions exist but webhooks are not firing');
    } else {
      console.log('✅ RevenueCat webhooks appear to be working');
    }

    process.exit(0);

  } catch (error) {
    console.error('\n❌ Investigation Error:', error.message);
    console.error(error);
    process.exit(1);
  }
}

investigateRevenueCat();
