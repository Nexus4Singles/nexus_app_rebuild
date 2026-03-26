#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function analyzeAndroidPattern() {
  const db = admin.firestore();
  
  console.log('\n═══════════════════════════════════════════════════════════');
  console.log('ANALYZING ANDROID SUBSCRIPTION PATTERN');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  // Get ALL users with active subscriptions
  const usersSnapshot = await db
    .collection('users')
    .where('subscription.isActive', '==', true)
    .get();
  
  console.log(`Total users with active subscriptions: ${usersSnapshot.size}\n`);
  
  let androidUsers = {
    withOptimistic: [],
    withoutOptimistic: [],
  };
  
  let iosUsers = {
    withOptimistic: [],
    withoutOptimistic: [],
  };
  
  let unknownPlatform = {
    withOptimistic: [],
    withoutOptimistic: [],
  };
  
  for (const doc of usersSnapshot.docs) {
    const userData = doc.data();
    const subscription = userData.subscription || {};
    const hasOptimistic = subscription.optimisticRecord === true;
    const validatedBy = subscription.validatedBy || 'unknown';
    
    // Try to infer platform
    let platform = 'unknown';
    const packageId = subscription.packageId || '';
    if (packageId.includes('monthly_premium') && !packageId.includes('nexus')) {
      platform = 'android';  // monthly_premium_v2 is Android
    } else if (packageId.includes('nexus_premium')) {
      platform = 'ios';  // nexus_premium_v2 is iOS
    }
    
    // Also check transaction history for clues
    if (platform === 'unknown') {
      const transactionsRef = doc.ref.collection('transactions');
      const txSnapshot = await transactionsRef.limit(1).get();
      if (txSnapshot.size > 0) {
        const tx = txSnapshot.docs[0].data();
        const source = (tx.source || tx.platform || '').toLowerCase();
        if (source.includes('android') || source.includes('play')) {
          platform = 'android';
        } else if (source.includes('ios') || source.includes('app_store') || source.includes('apple')) {
          platform = 'ios';
        }
      }
    }
    
    const userInfo = {
      id: doc.id,
      email: userData.email,
      tier: subscription.tier,
      validatedBy: validatedBy,
      packageId: packageId,
    };
    
    if (platform === 'android') {
      if (hasOptimistic) {
        androidUsers.withOptimistic.push(userInfo);
      } else {
        androidUsers.withoutOptimistic.push(userInfo);
      }
    } else if (platform === 'ios') {
      if (hasOptimistic) {
        iosUsers.withOptimistic.push(userInfo);
      } else {
        iosUsers.withoutOptimistic.push(userInfo);
      }
    } else {
      if (hasOptimistic) {
        unknownPlatform.withOptimistic.push(userInfo);
      } else {
        unknownPlatform.withoutOptimistic.push(userInfo);
      }
    }
  }
  
  console.log('ANDROID USERS:');
  console.log(`  ✅ With optimisticRecord=${androidUsers.withOptimistic.length}`);
  console.log(`  ❌ Without optimisticRecord=${androidUsers.withoutOptimistic.length}`);
  
  if (androidUsers.withOptimistic.length > 0) {
    console.log('\n  Examples with optimisticRecord:');
    androidUsers.withOptimistic.slice(0, 3).forEach(u => {
      console.log(`    - ${u.email} (${u.validatedBy})`);
    });
  }
  
  if (androidUsers.withoutOptimistic.length > 0) {
    console.log('\n  Examples without optimisticRecord:');
    androidUsers.withoutOptimistic.slice(0, 3).forEach(u => {
      console.log(`    - ${u.email} (${u.validatedBy})`);
    });
  }
  
  console.log('\niOS USERS:');
  console.log(`  ✅ With optimisticRecord=${iosUsers.withOptimistic.length}`);
  console.log(`  ❌ Without optimisticRecord=${iosUsers.withoutOptimistic.length}`);
  
  if (iosUsers.withOptimistic.length > 0) {
    console.log('\n  Examples with optimisticRecord:');
    iosUsers.withOptimistic.slice(0, 3).forEach(u => {
      console.log(`    - ${u.email} (${u.validatedBy})`);
    });
  }
  
  console.log('\nUNKNOWN PLATFORM:');
  console.log(`  ✅ With optimisticRecord=${unknownPlatform.withOptimistic.length}`);
  console.log(`  ❌ Without optimisticRecord=${unknownPlatform.withoutOptimistic.length}`);
  
  console.log('\n═══════════════════════════════════════════════════════════');
  console.log('PATTERN ANALYSIS');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  // Calculate percentages
  const androidTotal = androidUsers.withOptimistic.length + androidUsers.withoutOptimistic.length;
  const iosTotal = iosUsers.withOptimistic.length + iosUsers.withoutOptimistic.length;
  
  if (androidTotal > 0) {
    const androidOptPercentage = ((androidUsers.withOptimistic.length / androidTotal) * 100).toFixed(1);
    console.log(`Android: ${androidOptPercentage}% have optimisticRecord (${androidUsers.withOptimistic.length}/${androidTotal})`);
  }
  
  if (iosTotal > 0) {
    const iosOptPercentage = ((iosUsers.withOptimistic.length / iosTotal) * 100).toFixed(1);
    console.log(`iOS: ${iosOptPercentage}% have optimisticRecord (${iosUsers.withOptimistic.length}/${iosTotal})`);
  }
  
  console.log('\n🔍 CONCLUSION:\n');
  
  if (androidUsers.withOptimistic.length === 0 && androidUsers.withoutOptimistic.length > 0) {
    console.log('⚠️  SYSTEMIC ANDROID ISSUE:');
    console.log(`   ALL ${androidTotal} Android users are missing optimisticRecord`);
    console.log('   This is NOT specific to one transaction');
    console.log('   The Android app code does not create optimistic records');
  } else if (androidUsers.withOptimistic.length > 0) {
    const percent = ((androidUsers.withOptimistic.length / androidTotal) * 100).toFixed(1);
    console.log(`PARTIAL ANDROID ISSUE:`);
    console.log(`   Only ${percent}% of Android users have optimisticRecord`);
    console.log(`   This suggests Android implementation is inconsistent`);
  } else {
    console.log('✅ No Android users found to analyze');
  }
  
  console.log('\n');
  process.exit(0);
}

analyzeAndroidPattern().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
