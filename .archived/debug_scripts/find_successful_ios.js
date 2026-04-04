#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function getRecentSubscriptions() {
  const db = admin.firestore();
  
  console.log('\n🔍 FINDING iOS USERS WHO SUBSCRIBED TODAY\n');
  
  // Get today's date range
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  
  // Find users with recent subscription activations
  const usersSnapshot = await db
    .collection('users')
    .where('subscription.isActive', '==', true)
    .get();
  
  let recentActivations = [];
  
  for (const doc of usersSnapshot.docs) {
    const userData = doc.data();
    const validatedAt = userData.subscription?.validatedAt?.toDate?.() || new Date(userData.subscription?.validatedAt);
    
    // Only include recent ones (last 24 hours)
    if (validatedAt && validatedAt > today && validatedAt < tomorrow) {
      recentActivations.push({
        id: doc.id,
        email: userData.email,
        name: userData.username || userData.name,
        validatedAt: validatedAt,
        tier: userData.subscription?.tier,
        validatedBy: userData.subscription?.validatedBy,
      });
    }
  }
  
  if (recentActivations.length === 0) {
    console.log('No recent subscription activations found in the last 24 hours');
    process.exit(0);
  }
  
  console.log(`Found ${recentActivations.length} recent activation(s):\n`);
  
  // Sort by most recent
  recentActivations.sort((a, b) => b.validatedAt - a.validatedAt);
  
  recentActivations.forEach((user, idx) => {
    console.log(`${idx + 1}. ${user.name || 'Unknown'} (${user.email})`);
    console.log(`   Subscribed: ${user.validatedAt.toISOString()}`);
    console.log(`   Tier: ${user.tier}`);
    console.log(`   Activated by: ${user.validatedBy}`);
    console.log(`   (NOT manual - likely iOS)\n`);
  });
  
  // Now investigate the first non-manual one
  const iosUser = recentActivations.find(u => u.validatedBy !== 'manual_activation' && u.validatedBy !== 'manual_activation_ios_corrected');
  
  if (!iosUser) {
    console.log('No iOS users found in recent activations');
    process.exit(0);
  }
  
  console.log('═══════════════════════════════════════════════════════════');
  console.log('COMPARING: iOS USER WHO SUCCEEDED');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  const userDoc = await db.collection('users').doc(iosUser.id).get();
  const userData = userDoc.data();
  
  console.log(`User: ${iosUser.email}`);
  console.log(`ID: ${iosUser.id}\n`);
  
  // Check transactions
  const transactionsRef = userDoc.ref.collection('transactions');
  const txSnapshot = await transactionsRef.get();
  
  console.log(`Transaction records: ${txSnapshot.size > 0 ? '✅ YES' : '❌ NO'}`);
  if (txSnapshot.size > 0) {
    txSnapshot.forEach((doc, index) => {
      const tx = doc.data();
      console.log(`\n  Transaction ${index + 1}:`);
      console.log(`    Platform: ${tx.source || tx.platform || 'unknown'}`);
      console.log(`    Amount: ${tx.amount || 'N/A'}`);
      console.log(`    Date: ${tx.transactionDate?.toDate?.()?.toISOString() || tx.timestamp?.toDate?.()?.toISOString()}`);
    });
  }
  
  console.log(`\nSubscription record: ✅ YES`);
  console.log(`  Tier: ${userData.subscription?.tier}`);
  console.log(`  Expiry: ${userData.subscription?.expiryDate?.toDate?.()?.toLocaleDateString()}`);
  console.log(`  isActive: ${userData.subscription?.isActive}`);
  console.log(`  revenueCatCustomerId: ${userData.subscription?.revenueCatCustomerId || 'null'}`);
  
  process.exit(0);
}

getRecentSubscriptions().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
