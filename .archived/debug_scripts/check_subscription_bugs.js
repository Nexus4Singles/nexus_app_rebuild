#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

(async () => {
  console.log('\n📊 SUBSCRIPTION CONFIGURATION BUG INVESTIGATION\n');
  
  // Get all users to check subscription patterns
  const snapshot = await db.collection('users').limit(50).get();
  
  let newFormat = 0;
  let legacyFormat = 0;
  let noSub = 0;
  let issuedCount = 0;

  console.log('Checking 50 random users for subscription patterns:\n');
  
  snapshot.docs.forEach(doc => {
    const data = doc.data();
    const hasNew = data.subscription && data.subscription.isActive;
    const hasLegacy = data.onPremium && data.subExpDate;
    
    if (hasNew) {
      newFormat++;
    } else if (hasLegacy) {
      legacyFormat++;
    } else {
      noSub++;
    }

    // Check for potential issues
    if (hasNew) {
      const tier = data.subscription.tier;
      const expiry = data.subscription.expiryDate?.toDate?.();
      const isExpired = expiry && expiry < new Date();
      
      if (!expiry && data.subscription.isActive) {
        console.log('⚠️  ' + data.email + ': No expiry date but isActive=true');
        issuedCount++;
      }
      if (isExpired) {
        console.log('⚠️  ' + data.email + ': Subscription EXPIRED on ' + expiry.toISOString());
        issuedCount++;
      }
    }
  });
  
  console.log('\n📈 STATISTICS:');
  console.log('  Users with NEW subscription format: ' + newFormat);
  console.log('  Users with LEGACY format: ' + legacyFormat);
  console.log('  Users with NO subscription: ' + noSub);
  console.log('  Issues found: ' + issuedCount);
  
  console.log('\n🔍 KEY FINDING: ' + (newFormat === 0 ? '❌ NO NEW FORMAT SUBSCRIPTIONS!' : '✅ Found ' + newFormat + ' new format'));
  
  console.log('\n📋 ROOT CAUSES TO INVESTIGATE:');
  console.log('  1. ❌ Flutterwave webhooks NOT FIRING - endpoint not configured');
  console.log('  2. ❌ RevenueCat webhooks NOT FIRING - endpoint not configured');  
  console.log('  3. ❌ Webhooks only creating LEGACY format (not NEW format)');
  console.log('  4. ⚠️  App-side bug: Not recognizing subscriptions properly');
  console.log('  5. ⚠️  Users need to restart app or log out/in');
  
  process.exit(0);
})();
