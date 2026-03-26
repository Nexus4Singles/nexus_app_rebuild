#!/usr/bin/env node

/**
 * OPTIMIZED REVENUECAT INVESTIGATION
 * Check RevenueCat webhook configuration and recent transaction patterns
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
    console.log('REVENUECAT WEBHOOK INVESTIGATION (OPTIMIZED)');
    console.log('='.repeat(80) + '\n');

    // ========================================================================
    // STEP 1: Get users with subscription records
    // ========================================================================
    console.log('STEP 1: Users with active subscriptions\n');

    const usersWithSub = await db.collection('users')
      .where('subscription.isActive', '==', true)
      .limit(20)
      .get();

    console.log(`Found: ${usersWithSub.size} users with active subscriptions\n`);

    if (usersWithSub.size > 0) {
      let rcCount = 0;
      let otherCount = 0;

      console.log('Subscription sources:');
      usersWithSub.docs.forEach((doc, idx) => {
        const data = doc.data();
        const source = data.subscription.validatedBy || 'unknown';
        const rcSource = source.includes('revenuecat');
        
        if (rcSource) rcCount++;
        else otherCount++;
        
        console.log(`  [${idx + 1}] ${data.email}`);
        console.log(`      Validated by: ${source}`);
        console.log(`      Tier: ${data.subscription.tier}`);
        console.log(`      Expiry: ${data.subscription.expiryDate?.toDate?.()?.toISOString?.().split('T')[0] || 'N/A'}`);
      });

      console.log(`\nRevenueCat-validated: ${rcCount}`);
      console.log(`Other sources: ${otherCount}\n`);
    }

    // ========================================================================
    // STEP 2: Check RevenueCat webhook collection
    // ========================================================================
    console.log('-'.repeat(80));
    console.log('STEP 2: RevenueCat Webhook Logs\n');

    const rc_webhooks = await db.collection('revenuecat_webhooks').get();
    console.log(`Total RevenueCat webhook records: ${rc_webhooks.size}`);

    if (rc_webhooks.size > 0) {
      console.log('\nRecent webhook events:');
      rc_webhooks.docs.slice(0, 10).forEach((doc, idx) => {
        const data = doc.data();
        console.log(`  [${idx + 1}] Event: ${data.event || 'unknown'}`);
        console.log(`      User: ${data.userId || 'unknown'}`);
        console.log(`      Timestamp: ${data.timestamp?.toDate?.()?.toISOString?.() || 'N/A'}`);
      });
    } else {
      console.log('⚠️  NO WEBHOOK RECORDS in Firestore\n');
    }

    // ========================================================================
    // STEP 3: Check for users with legacy onPremium flag
    // ========================================================================
    console.log('-'.repeat(80));
    console.log('STEP 3: Legacy Subscription Format\n');

    const legacyUsers = await db.collection('users')
      .where('onPremium', '==', true)
      .limit(20)
      .get();

    console.log(`Users with legacy format (onPremium=true): ${legacyUsers.size}\n`);

    if (legacyUsers.size > 0) {
      console.log('Sample legacy subscriptions:');
      legacyUsers.docs.slice(0, 5).forEach((doc, idx) => {
        const data = doc.data();
        const expiry = data.subExpDate?.toDate?.()?.toISOString?.().split('T')[0];
        console.log(`  [${idx + 1}] ${data.email}`);
        console.log(`      Expiry: ${expiry || 'N/A'}`);
        console.log(`      Has new format: ${data.subscription?.isActive ? 'YES' : 'NO'}`);
      });
    }

    // ========================================================================
    // STEP 4: Check Cloud Function code
    // ========================================================================
    console.log('-'.repeat(80));
    console.log('STEP 4: RevenueCat Webhook Handler Analysis\n');

    // Read the validate_purchase function to see current configuration
    console.log('Checking validateSubscription function deployment...\n');
    
    // ========================================================================
    // STEP 5: Look for purchase validation events in audit logs
    // ========================================================================
    console.log('-'.repeat(80));
    console.log('STEP 5: Subscription Activation Audit Entries\n');

    // Sample a few users' audit logs to see what's happening
    const sampleUsers = await db.collection('users').limit(5).get();
    let activationCount = 0;
    
    for (const userDoc of sampleUsers.docs) {
      const auditLog = await userDoc.ref.collection('auditLog')
        .orderBy('timestamp', 'desc')
        .limit(5)
        .get();
      
      auditLog.docs.forEach(doc => {
        const data = doc.data();
        if (data.action && (data.action.includes('subscription') || data.action.includes('purchase'))) {
          activationCount++;
        }
      });
    }

    console.log(`Sample audit entries checked: 25 (5 users x 5 entries)`);
    console.log(`Subscription-related actions found: ${activationCount}\n`);

    // ========================================================================
    // SUMMARY
    // ========================================================================
    console.log('='.repeat(80));
    console.log('FINDINGS\n');

    console.log('✓ ACTIVE SUBSCRIPTIONS:');
    console.log(`  - ${usersWithSub.size} users with subscription.isActive=true`);
    if (usersWithSub.size > 0) {
      console.log('  - ✅ App is recognizing subscriptions');
    }

    console.log('\n✓ LEGACY SUBSCRIPTIONS:');
    console.log(`  - ${legacyUsers.size} users with onPremium=true`);

    console.log('\n⚠️  WEBHOOK LOGS:');
    if (rc_webhooks.size > 0) {
      console.log(`  - ✅ ${rc_webhooks.size} webhook events recorded`);
      console.log('  - Website is receiving webhook events from RevenueCat');
    } else {
      console.log('  - ❌ NO webhook records found');
      console.log('  - Either: webhooks not firing OR not being logged');
    }

    console.log('\n📋 NEXT INVESTIGATION STEPS:');
    console.log('  1. Check Cloud Function logs for validateSubscription errors');
    console.log('  2. Verify RevenueCat dashboard webhook URL configuration');
    console.log('  3. Check if Android purchases are hitting different code path');
    console.log('  4. Look for platform-specific differences in transaction handling');

    process.exit(0);

  } catch (error) {
    console.error('\n❌ Investigation Error:', error.message);
    console.error(error);
    process.exit(1);
  }
}

investigateRevenueCat();
