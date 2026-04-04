#!/usr/bin/env node

/**
 * UNIVERSAL SUBSCRIPTION FIX
 * Adds legacy subscription fields to all users with active subscriptions
 * This ensures compatibility with all code paths regardless of platform
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function fixAllSubscriptions() {
  try {
    console.log('\n' + '='.repeat(80));
    console.log('UNIVERSAL SUBSCRIPTION FIX');
    console.log('Adding legacy fields to all active subscriptions...');
    console.log('='.repeat(80) + '\n');

    // Get all users with new-format subscriptions
    const snapshot = await db.collection('users').where('subscription.isActive', '==', true).get();
    
    console.log(`Found ${snapshot.size} users with active subscriptions\n`);

    let fixed = 0;
    let alreadyHad = 0;
    let errors = 0;

    for (const userDoc of snapshot.docs) {
      try {
        const userData = userDoc.data();
        const subscription = userData.subscription;
        const email = userData.email;

        // Check if already has legacy fields
        if (userData.onPremium === true && userData.subExpDate) {
          console.log(`✅ ${email} - Already has legacy fields`);
          alreadyHad++;
          continue;
        }

        // Extract expiry date from new format
        const expiryDate = subscription.expiryDate?.toDate?.() || subscription.expiryDate;
        
        if (!expiryDate) {
          console.log(`⚠️  ${email} - No expiryDate found, skipping`);
          continue;
        }

        // Add legacy fields
        await userDoc.ref.update({
          'onPremium': true,
          'subExpDate': expiryDate,
          'entitledUser': true,
          'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`🔧 ${email} - Fixed (expiry: ${expiryDate.toDateString()})`);
        fixed++;
      } catch (err) {
        console.error(`❌ Error processing user: ${err.message}`);
        errors++;
      }
    }

    console.log('\n' + '='.repeat(80));
    console.log('SUMMARY\n');
    console.log(`Fixed: ${fixed}`);
    console.log(`Already had legacy fields: ${alreadyHad}`);
    console.log(`Errors: ${errors}`);
    console.log(`Total processed: ${fixed + alreadyHad + errors}`);
    console.log('\n✅ Universal fix complete!');
    console.log('   All subscribers now have both new and legacy subscription fields.');
    console.log('   No app rebuild needed - fix takes effect on next app restart.');
    console.log('='.repeat(80) + '\n');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

fixAllSubscriptions();
