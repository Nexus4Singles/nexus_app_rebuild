#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function updateSubscriptionExpiry(email, newExpiryDate) {
  try {
    console.log(`\n🔄 Updating subscription expiry for: ${email}`);
    
    const snapshot = await db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (snapshot.empty) {
      console.log('❌ User not found');
      process.exit(1);
    }

    const userDoc = snapshot.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();

    console.log(`✅ Found user: ${userId}`);
    console.log(`   Name: ${userData.username || userData.name}`);
    console.log(`   Current Expiry: ${userData.subscription?.expiryDate?.toDate?.().toLocaleDateString() || 'N/A'}`);

    const expiryDate = new Date(newExpiryDate);
    if (isNaN(expiryDate.getTime())) {
      console.error(`❌ Invalid date format: ${newExpiryDate}`);
      console.error(`   Use format: YYYY-MM-DD (e.g., 2026-04-18)`);
      process.exit(1);
    }

    await db.collection('users').doc(userId).update({
      'subscription.expiryDate': expiryDate,
      'subscription.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('\n✅ Subscription expiry updated');
    console.log('   User: ' + userId);
    console.log('   Email: ' + email);
    console.log('   New Expiry: ' + expiryDate.toLocaleDateString());
    console.log('');

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

const email = process.argv[2];
const expiryDate = process.argv[3];

if (!email || !expiryDate) {
  console.error('Usage: node update_subscription_expiry.js <email> <YYYY-MM-DD>');
  process.exit(1);
}

updateSubscriptionExpiry(email, expiryDate);
