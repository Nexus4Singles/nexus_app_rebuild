#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function checkSpecificUsers() {
  try {
    const users = [
      'nexusgodlydatingapp@gmail.com',
      'nexus4singles@gmail.com',
      'contact@nexus4singles.com',
    ];

    for (const email of users) {
      const snapshot = await db
        .collection('users')
        .where('email', '==', email)
        .get();

      if (snapshot.empty) {
        console.log(`\n❌ User not found: ${email}`);
        continue;
      }

      const user = snapshot.docs[0].data();
      const uid = snapshot.docs[0].id;

      console.log(`\n${'='.repeat(60)}`);
      console.log(`📧 USER: ${email}`);
      console.log(`UID: ${uid}`);
      console.log(`Username: ${user.username || 'N/A'}`);

      const visibilityFields = [
        'isAdmin',
        'disabled',
        'accountStatus',
        'status',
        'hidden',
        'isHidden',
        'testAccount',
        'internalAccount',
        'archived',
        'banned',
        'suspended',
        'visible',
        'searchable',
        'showInSearch',
      ];

      console.log('\n🔍 Visibility/Search Fields:');
      visibilityFields.forEach(field => {
        if (user[field] !== undefined) {
          console.log(`  ${field}: ${JSON.stringify(user[field])}`);
        }
      });

      console.log('\n📋 Profile Status:');
      console.log(
        `  gender: ${user.gender || 'N/A'}`,
      );
      console.log(
        `  age: ${user.age || 'N/A'}`,
      );
      if (user.dating) {
        console.log(
          `  dating.verificationStatus: ${user.dating.verificationStatus || 'N/A'}`,
        );
        console.log(
          `  dating.countryOfResidence: ${user.dating.countryOfResidence || 'N/A'}`,
        );
      } else {
        console.log(`  dating: (no dating object)`);
      }
      console.log(
        `  registration_progress: ${user.registration_progress || 'N/A'}`,
      );
    }

    console.log(`\n${'='.repeat(60)}\n`);
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await admin.app().delete();
  }
}

checkSpecificUsers().catch(console.error);
