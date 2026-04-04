#!/usr/bin/env node

/**
 * Comprehensive Subscription Investigation Script
 * Analyzes subscription configuration issues across multiple users and systems
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function investigateSubscriptions() {
  try {
    console.log('\n' + '='.repeat(80));
    console.log('SUBSCRIPTION CONFIGURATION INVESTIGATION');
    console.log('='.repeat(80) + '\n');

    // ========================================================================
    // 1. CHECK SUBSCRIPTION FORMAT ISSUES
    // ========================================================================
    console.log('📊 ANALYSIS 1: Subscription Format & Data Structure\n');
    
    const usersSnapshot = await db.collection('users').limit(20).get();
    const subscriptionIssues = [];
    let totalUsers = 0;
    let usersWithSubscription = 0;
    let formatMismatches = 0;

    for (const doc of usersSnapshot.docs) {
      const userData = doc.data();
      totalUsers++;

      // Check if user has any subscription data
      const hasNewFormat = userData.subscription && userData.subscription.isActive;
      const hasLegacyFormat = userData.onPremium && userData.subExpDate;
      
      if (hasNewFormat || hasLegacyFormat) {
        usersWithSubscription++;
      }

      // Check for format mismatches or issues
      if (userData.subscription) {
        const tier = userData.subscription.tier;
        
        // Check if tier is in an unexpected format
        if (tier && !['monthly_premium', 'free', 'monthly', 'Premium', 'nexus_premium'].includes(tier)) {
          subscriptionIssues.push({
            userId: doc.id,
            email: userData.email,
            issue: 'Unrecognized tier format',
            tier: tier,
          });
          formatMismatches++;
        }

        // Check for subscription.isActive=true but no expiry date
        if (userData.subscription.isActive && !userData.subscription.expiryDate) {
          console.log(`  ⚠️  User ${doc.id} (${userData.email}): isActive=true but NO expiryDate`);
        }

        // Check for expired subscriptions
        if (userData.subscription.expiryDate) {
          const expiryDate = userData.subscription.expiryDate.toDate?.() || userData.subscription.expiryDate;
          if (expiryDate < new Date()) {
            console.log(`  ⚠️  EXPIRED: ${userData.email} - expired on ${expiryDate.toISOString()}`);
          }
        }
      }

      // Check for mixed format (new AND legacy)
      if (hasNewFormat && hasLegacyFormat) {
        console.log(`  ℹ️  User ${doc.id} (${userData.email}): Has BOTH new and legacy formats`);
      }
    }

    console.log(`\n  Total users checked: ${totalUsers}`);
    console.log(`  Users with subscription data: ${usersWithSubscription}`);
    console.log(`  Format mismatches found: ${formatMismatches}`);

    if (subscriptionIssues.length > 0) {
      console.log('\n  ⚠️  ISSUES FOUND:');
      subscriptionIssues.forEach(issue => {
        console.log(`     - ${issue.email}: ${issue.issue} (tier="${issue.tier}")`);
      });
    }

    // ========================================================================
    // 2. CHECK TIER PARSING LOGIC
    // ========================================================================
    console.log('\n' + '-'.repeat(80));
    console.log('📊 ANALYSIS 2: Tier Parsing Issue (SubscriptionTier.fromId)\n');

    const tierTestCases = [
      'monthly_premium',
      'monthly',
      'free',
      'Premium',
      'nexus_premium',
      'monthly_premium_v2',
      'nexus_premium_v2',
      'unknown_tier',
    ];

    const tierMapping = {};
    tierTestCases.forEach(id => {
      // Simulate the fromId logic
      let recognizedAs = 'free (UNRECOGNIZED)';
      if (id === 'monthly' ||
          id === 'Premium' ||
          id === 'nexus_premium' ||
          id.includes('monthly_premium') ||
          id.includes('nexus_premium')) {
        recognizedAs = 'monthly_premium ✓';
      } else if (id === 'free') {
        recognizedAs = 'free ✓';
      }
      tierMapping[id] = recognizedAs;
    });

    console.log('  Tier Recognition Results:');
    tierTestCases.forEach(id => {
      const result = tierMapping[id];
      const icon = result.includes('✓') ? '✅' : '❌';
      console.log(`    ${icon} "${id}" → ${result}`);
    });

    // ========================================================================
    // 3. CHECK WEBHOOK CONFIGURATION
    // ========================================================================
    console.log('\n' + '-'.repeat(80));
    console.log('📊 ANALYSIS 3: Webhook Configuration & Recent Activity\n');

    // Check for recent webhook logs
    const recentWebhooks = await db.collection('flutterwave_webhooks').orderBy('timestamp', 'desc').limit(5).get();
    const recentFailedWebhooks = await db.collection('flutterwave_failed_webhooks').orderBy('timestamp', 'desc').limit(5).get();
    const recentRevenueCatWebhooks = await db.collection('revenuecat_webhooks').orderBy('timestamp', 'desc').limit(5).get();

    console.log(`  Flutterwave webhook records: ${recentWebhooks.size}`);
    console.log(`  Flutterwave failed webhooks: ${recentFailedWebhooks.size}`);
    console.log(`  RevenueCat webhook records: ${recentRevenueCatWebhooks.size}`);

    if (recentWebhooks.size > 0) {
      console.log('\n  Recent Flutterwave webhooks:');
      recentWebhooks.docs.forEach(doc => {
        console.log(`    - ${doc.data().timestamp?.toDate?.()?.toISOString?.()} ${doc.data().status}`);
      });
    } else {
      console.log('\n  ⚠️  NO FLUTTERWAVE WEBHOOKS - This suggests the webhook endpoint is not configured!');
    }

    // ========================================================================
    // 4. AUDIT LOG ANALYSIS
    // ========================================================================
    console.log('\n' + '-'.repeat(80));
    console.log('📊 ANALYSIS 4: Recent Subscription Activations (Audit Logs)\n');

    const auditLogs = await db.collectionGroup('auditLog')
      .where('action', 'in', ['subscription_activated_external', 'subscription_manually_activated'])
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();

    console.log(`  Recent subscription activations: ${auditLogs.size}`);
    auditLogs.docs.forEach(doc => {
      const data = doc.data();
      console.log(`    - ${data.timestamp?.toDate?.()?.toISOString?.()} via ${data.provider} (${data.action})`);
    });

    // ========================================================================
    // 5. NEW FORMAT ADOPTION
    // ========================================================================
    console.log('\n' + '-'.repeat(80));
    console.log('📊 ANALYSIS 5: Migration to New Subscription Format\n');

    let newFormatCount = 0;
    let legacyFormatCount = 0;
    let noFormatCount = 0;

    const allUsers = await db.collection('users').limit(100).get();
    allUsers.docs.forEach(doc => {
      const userData = doc.data();
      if (userData.subscription && userData.subscription.isActive) {
        newFormatCount++;
      } else if (userData.onPremium) {
        legacyFormatCount++;
      } else {
        noFormatCount++;
      }
    });

    console.log(`  Users with NEW format: ${newFormatCount}`);
    console.log(`  Users with LEGACY format: ${legacyFormatCount}`);
    console.log(`  Users with NO subscription: ${noFormatCount}`);

    if (legacyFormatCount > 0 && newFormatCount === 0) {
      console.log('\n  ⚠️  MIGRATION INCOMPLETE: All users still using legacy format!');
      console.log('      Webhook handlers may not be creating new format properly.');
    }

    // ========================================================================
    // 6. SPECIFIC USER CHECKS
    // ========================================================================
    console.log('\n' + '-'.repeat(80));
    console.log('📊 ANALYSIS 6: Spot Check - Users Claiming No Benefits\n');

    // Find users with active subscriptions but check what the app would see
    const premiumUsers = await db.collection('users')
      .where('subscription.isActive', '==', true)
      .limit(5)
      .get();

    console.log(`  Checking ${premiumUsers.docs.length} premium users:\n`);

    for (const doc of premiumUsers.docs) {
      const userData = doc.data();
      const tier = userData.subscription?.tier;
      
      let tierWillBeRecognized = false;
      if (tier === 'monthly' ||
          tier === 'Premium' ||
          tier === 'nexus_premium' ||
          tier?.includes('monthly_premium') ||
          tier?.includes('nexus_premium')) {
        tierWillBeRecognized = true;
      }

      const expiryDate = userData.subscription?.expiryDate?.toDate?.() || userData.subscription?.expiryDate;
      const isExpired = expiryDate && expiryDate < new Date();

      const status = tierWillBeRecognized && !isExpired ? '✅ OK' : '❌ ISSUE';
      
      console.log(`  ${status} - ${userData.email}`);
      console.log(`       Tier: ${tier} ${tierWillBeRecognized ? '(recognized)' : '(NOT RECOGNIZED)'}`);
      console.log(`       Expires: ${expiryDate?.toISOString?.()}`);
      if (isExpired) console.log(`       ⚠️  EXPIRED`);
      console.log('');
    }

    // ========================================================================
    // SUMMARY
    // ========================================================================
    console.log('='.repeat(80));
    console.log('SUMMARY & RECOMMENDATIONS\n');

    const issues = [];
    if (formatMismatches > 0) issues.push(`❌ Found ${formatMismatches} tier format mismatches`);
    if (recentWebhooks.size === 0) issues.push('❌ No Flutterwave webhooks (endpoint not configured?)');
    if (legacyFormatCount > 0 && newFormatCount === 0) issues.push('❌ Webhooks not creating new subscription format');
    
    if (issues.length === 0) {
      console.log('✅ No critical issues found in subscription configuration.');
      console.log('   Issue may be user-specific or app-side.');
    } else {
      console.log('IDENTIFIED ISSUES:');
      issues.forEach(issue => console.log(`  ${issue}`));
    }

    console.log('\nRECOMMENDED ACTIONS:');
    console.log('  1. Check Flutterwave dashboard webhook configuration');
    console.log('  2. Verify webhook endpoint URL matches deployed Cloud Function');
    console.log('  3. Review subscription tier values in Firestore');
    console.log('  4. Check app-side isPremiumProvider logic');
    console.log('  5. Verify subscription.tier parsing in SubscriptionTier.fromId()');
    console.log('  6. Check chat service premium check logic\n');

    process.exit(0);

  } catch (error) {
    console.error('\n❌ Investigation Error:', error.message);
    console.error(error);
    process.exit(1);
  }
}

investigateSubscriptions();
