#!/usr/bin/env node

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin using the service account
const serviceAccountPath = path.join(__dirname, 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function activateUserSubscription(email, expiryDateString) {
  try {
    const db = admin.firestore();
    
    console.log(`\n🔍 Looking up user by email: ${email}`);
    
    // Find user by email
    const usersSnapshot = await db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.log(`❌ No user found with email: ${email}\n`);
      process.exit(1);
    }

    const userDoc = usersSnapshot.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();

    console.log(`✅ Found user: ${userId}`);
    console.log(`   Name: ${userData.username || userData.name}`);
    console.log(`   Email: ${userData.email}`);

    // Parse expiry date
    let expiryDate;
    if (expiryDateString) {
      expiryDate = new Date(expiryDateString);
      if (isNaN(expiryDate.getTime())) {
        console.error(`❌ Invalid date format: ${expiryDateString}`);
        console.error(`   Use format: YYYY-MM-DD (e.g., 2026-04-15)`);
        process.exit(1);
      }
    } else {
      console.error(`❌ No expiry date provided`);
      process.exit(1);
    }

    console.log(`\n📋 Subscription Details:`);
    console.log(`   Tier: monthly_premium`);
    console.log(`   Start Date: ${new Date().toISOString()}`);
    console.log(`   Expiry Date: ${expiryDate.toISOString()}`);
    console.log(`   Auto Renew: true`);

    // Create subscription object
    const subscriptionData = {
      isActive: true,
      tier: 'monthly_premium',
      startDate: admin.firestore.FieldValue.serverTimestamp(),
      expiryDate: expiryDate,
      autoRenew: true,
      revenueCatCustomerId: null,
      revenueCatTransactionId: null,
      validatedAt: admin.firestore.FieldValue.serverTimestamp(),
      validatedBy: 'manual_activation',
      verificationStatus: 'verified',
    };

    // Update user document
    const userRef = db.collection('users').doc(userId);
    await userRef.update({
      subscription: subscriptionData,
      onPremium: true, // Legacy flag for backward compatibility
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`\n✅ Subscription activated successfully!`);
    console.log(`   User: ${userId}`);
    console.log(`   Email: ${email}`);
    console.log(`   Subscription Active Until: ${expiryDate.toLocaleDateString()}`);

    // Create audit log
    await userRef.collection('auditLog').add({
      action: 'subscription_manually_activated',
      provider: 'manual',
      tier: 'monthly_premium',
      expiryDate: expiryDate,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      reason: 'User payment received - manual activation by admin',
      activatedBy: 'admin',
    });

    console.log(`\n📝 Audit log created`);

    // Create notification for user
    await userRef.collection('notifications').add({
      type: 'subscription_activated',
      title: '✅ Subscription Active',
      body: `Your monthly premium subscription is now active!`,
      payload: {
        type: 'subscription_activated',
        title: '✅ Subscription Active',
        body: `Your premium subscription is active until ${expiryDate.toLocaleDateString()}`,
        tier: 'monthly_premium',
        expiryDate: expiryDate.toISOString(),
        route: '/subscription',
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isSent: false,
    });

    console.log(`📬 Notification queued for user\n`);

    process.exit(0);
  } catch (error) {
    console.error(`\n❌ Error: ${error.message}`);
    console.error(error);
    process.exit(1);
  }
}

// Get email and expiry date from command line arguments
const email = process.argv[2];
const expiryDate = process.argv[3];

if (!email) {
  console.error(`
Usage: node activate_user_subscription.js <email> <expiry-date>

Arguments:
  <email>         User email (e.g., arc.prosperchukwuka@gmail.com)
  <expiry-date>   Expiry date in YYYY-MM-DD format (e.g., 2026-04-15)

Example:
  node activate_user_subscription.js arc.prosperchukwuka@gmail.com 2026-04-15
  `);
  process.exit(1);
}

activateUserSubscription(email, expiryDate);
