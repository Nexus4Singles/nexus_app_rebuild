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

async function fixUserByEmail(email) {
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
    console.log(`   Username: ${userData.username || userData.name}`);
    console.log(`   Email: ${userData.email}`);
    console.log(`   Current onPremium: ${userData.onPremium}`);
    console.log(`   Current subExpDate: ${userData.subExpDate?.toDate?.() || userData.subExpDate}`);
    console.log(`   Current subscription object: ${userData.subscription ? 'EXISTS' : 'MISSING'}`);

    // Check if user has v1 subscription
    if (!(userData.onPremium && userData.subExpDate)) {
      console.log(`❌ User has no active v1 subscription\n`);
      process.exit(1);
    }

    // Check if already has v2 subscription
    if (userData.subscription && userData.subscription.isActive) {
      console.log(`⚠️  User already has v2 subscription structure\n`);
      process.exit(0);
    }

    // Create v2 subscription structure
    const expiryDate = userData.subExpDate;
    const updateData = {
      subscription: {
        isActive: true,
        tier: 'monthly_premium',
        startDate: userData.lastPaymentDate || admin.firestore.FieldValue.serverTimestamp(),
        expiryDate: expiryDate,
        autoRenew: true,
        revenueCatCustomerId: null,
        revenueCatSubscriptionId: null
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    console.log(`\n📝 Updating user with v2 subscription structure...`);
    await userDoc.ref.update(updateData);

    console.log(`✅ FIXED: subscription for ${email} (user: ${userId})`);
    console.log(`   Subscription expires: ${expiryDate?.toDate?.()?.toISOString?.() || expiryDate}`);
    console.log(`\n✨ User can now access premium features immediately!`);
    console.log(`   No app update needed.\n`);

    process.exit(0);

  } catch (error) {
    console.error(`❌ Error:`, error.message);
    process.exit(1);
  }
}

// Get email from command line argument or use the default
const email = process.argv[2] || 'sunkykush007@gmail.com';
fixUserByEmail(email);
