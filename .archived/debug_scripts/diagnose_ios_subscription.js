const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function diagnoseSubscription() {
  const userId = 'YwCMlX39kcZH3F4WHb53twQsM1q1';
  
  console.log(`\n=== DIAGNOSING SUBSCRIPTION FOR iOS USER ===\n`);
  console.log(`User ID: ${userId}\n`);

  try {
    // 1. Get user data
    console.log('📋 Fetching user data...');
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.error(`❌ User not found`);
      process.exit(1);
    }

    const userData = userDoc.data();
    console.log(`✓ User found: ${userData.email}\n`);

    // 2. Check current subscription structure
    console.log('🔍 CHECKING SUBSCRIPTION STRUCTURE\n');
    
    const v2Sub = userData.subscription;
    const v1OnPremium = userData.onPremium;
    const v1SubExpDate = userData.subExpDate;
    const hasV2 = v2Sub && typeof v2Sub === 'object';
    const hasV1 = v1OnPremium === true || (v1SubExpDate !== undefined);
    
    console.log(`V2 Schema (subscription object): ${hasV2 ? '✓ EXISTS' : '✗ MISSING'}`);
    console.log(`V1 Schema (onPremium/subExpDate): ${hasV1 ? '✓ EXISTS' : '✗ MISSING'}\n`);

    // 3. Analyze V2 structure if present
    if (hasV2) {
      console.log('📊 V2 SUBSCRIPTION DETAILS:');
      console.log(`  - isActive: ${v2Sub.isActive}`);
      console.log(`  - tier: ${v2Sub.tier}`);
      console.log(`  - startDate: ${v2Sub.startDate?.toDate?.() || v2Sub.startDate}`);
      console.log(`  - expiryDate: ${v2Sub.expiryDate?.toDate?.() || v2Sub.expiryDate}`);
      console.log(`  - autoRenew: ${v2Sub.autoRenew}`);
      
      const expiry = v2Sub.expiryDate?.toDate?.() || new Date(v2Sub.expiryDate);
      const now = new Date();
      const isExpired = expiry < now;
      const isActive = v2Sub.isActive && !isExpired;
      
      console.log(`\n  Status: ${isActive ? '✅ ACTIVE' : (isExpired ? '⏰ EXPIRED' : '❌ INACTIVE')}\n`);
    } else {
      console.log('📊 V2 SUBSCRIPTION: NOT PRESENT\n');
    }

    // 4. Analyze V1 structure if present
    if (hasV1) {
      console.log('📊 V1 SUBSCRIPTION DETAILS (Legacy):');
      console.log(`  - onPremium: ${v1OnPremium}`);
      console.log(`  - subExpDate: ${v1SubExpDate?.toDate?.() || v1SubExpDate}`);
      console.log(`  - entitledUser: ${userData.entitledUser}\n`);
    } else {
      console.log('📊 V1 SUBSCRIPTION: NOT PRESENT\n');
    }

    // 5. Diagnose the issue
    console.log('🔎 DIAGNOSIS:\n');
    
    if (!hasV2 && hasV1) {
      console.log('⚠️  USER HAS OLD SCHEMA (V1 ONLY)');
      console.log('   Problem: App looks for subscription.isActive first');
      console.log('   Solution: User needs to:');
      console.log('            1. Update to latest build');
      console.log('            2. Log out and back in to trigger migration');
      console.log('            3. OR: We manually migrate their record\n');
    } else if (!hasV2 && !hasV1) {
      console.log('❌ NO SUBSCRIPTION FOUND');
      console.log('   Problem: User has no subscription records at all');
      console.log('   Solution: Manually create subscription (next step)\n');
    } else if (hasV2 && !v2Sub.isActive) {
      console.log('⚠️  V2 SUBSCRIPTION EXISTS BUT INACTIVE');
      console.log('   Problem: subscription.isActive = false');
      console.log('   Solution: Reactivate subscription\n');
    } else if (hasV2 && v2Sub.isActive) {
      const expiry = v2Sub.expiryDate?.toDate?.() || new Date(v2Sub.expiryDate);
      if (expiry < new Date()) {
        console.log('⏰ V2 SUBSCRIPTION EXPIRED');
        console.log(`   Problem: Subscription expired on ${expiry}`);
        console.log('   Solution: Renew subscription\n');
      } else {
        console.log('✅ SUBSCRIPTION IS ACTIVE AND VALID');
        console.log(`   Problem: Unclear why app shows as inactive`);
        console.log('   Solution: Check app cache, try logout/login\n');
      }
    }

    // 6. Check payment/transaction history
    console.log('💳 CHECKING TRANSACTION HISTORY\n');
    
    const transactionsSnapshot = await db
      .collection('users')
      .doc(userId)
      .collection('transactions')
      .orderBy('createdAt', 'desc')
      .limit(5)
      .get();

    if (transactionsSnapshot.empty) {
      console.log('   ℹ️  No transactions found\n');
    } else {
      console.log('   Recent transactions:');
      transactionsSnapshot.docs.forEach((doc, i) => {
        const tx = doc.data();
        console.log(`   ${i+1}. ${tx.status || 'pending'} - ${tx.amount} ${tx.currency} - ${tx.createdAt?.toDate?.() || tx.createdAt}`);
      });
      console.log('');
    }

    // 7. Recommendation
    console.log('📋 RECOMMENDATION:\n');
    console.log('Next step: Manually activate subscription with expiry April 28, 2026\n');

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

diagnoseSubscription();
