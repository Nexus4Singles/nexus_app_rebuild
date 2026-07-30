#!/usr/bin/env node

/**
 * Update markets/uk with gender counts from actual profiles
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, './serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function updateMarketProfileCounts() {
  console.log('📊 Updating UK market profile counts...\n');
  
  try {
    // Count verified UK profiles by gender
    console.log('🔎 Counting verified UK profiles...');
    
    const femaleSnap = await db
      .collection('users')
      .where('countryOfResidence', '==', 'United Kingdom')
      .where('verificationStatus', '==', 'verified')
      .where('gender', '==', 'female')
      .get();
    
    const maleSnap = await db
      .collection('users')
      .where('countryOfResidence', '==', 'United Kingdom')
      .where('verificationStatus', '==', 'verified')
      .where('gender', '==', 'male')
      .get();
    
    const femaleCount = femaleSnap.size;
    const maleCount = maleSnap.size;
    const totalCount = femaleCount + maleCount;
    
    console.log(`   ✅ Found ${femaleCount} verified female profiles`);
    console.log(`   ✅ Found ${maleCount} verified male profiles`);
    console.log(`   ✅ Total: ${totalCount} verified profiles\n`);
    
    if (totalCount === 0) {
      console.error('❌ No verified UK profiles found!');
      process.exit(1);
    }

    // Update markets/uk document
    console.log('📝 Updating markets/uk document...');
    await db
      .collection('markets')
      .doc('uk')
      .update({
        approvedProfileCount: totalCount,
        gender: {
          female: femaleCount,
          male: maleCount,
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log('✅ Market document updated!\n');
    console.log('📊 Updated fields:');
    console.log(`   approvedProfileCount: ${totalCount}`);
    console.log(`   gender.female: ${femaleCount}`);
    console.log(`   gender.male: ${maleCount}\n`);
    
    console.log('✨ Now the app should be able to fetch the carousel profiles!');

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }

  process.exit(0);
}

updateMarketProfileCounts();
