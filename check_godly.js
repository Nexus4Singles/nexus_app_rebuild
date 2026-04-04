const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

(async () => {
  try {
    const snap = await db
      .collection('users')
      .where('email', '==', 'nexusgodlydatingapp@gmail.com')
      .get();

    if (snap.empty) {
      console.log('User not found');
    } else {
      const u = snap.docs[0].data();
      console.log('\nnexusgodlydatingapp@gmail.com:');
      console.log('isAdmin:', u.isAdmin);
      console.log('disabled:', u.disabled);
      console.log('hidden:', u.hidden);
      console.log('isHidden:', u.isHidden);
      console.log('dating.verificationStatus:', u.dating?.verificationStatus);
      console.log('registration_progress:', u.registration_progress);
      console.log('gender:', u.gender);
      console.log('\n📋 All visibility fields:');
      const visFields = [
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
      visFields.forEach(f => {
        if (u[f] !== undefined) console.log(`  ${f}: ${u[f]}`);
      });
    }
  } catch (e) {
    console.error(e);
  } finally {
    admin.app().delete();
  }
})();
