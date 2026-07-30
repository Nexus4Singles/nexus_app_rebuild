const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const userId = 'sT7oObb7hUNHvU49oWpvmVFuCu53';

async function check() {
  try {
    const datingProf = await admin.firestore().collection('datingProfiles').doc(userId).get();
    
    console.log('\n📋 datingProfiles collection:');
    if (datingProf.exists) {
      const data = datingProf.data();
      console.log('✅ Document exists');
      console.log(JSON.stringify(data, null, 2));
    } else {
      console.log('❌ No datingProfiles/' + userId + ' document');
    }

    // Also check users/dating/profile
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (userDoc.exists) {
      const data = userDoc.data();
      console.log('\n📋 users/{uid}/dating/profile fields:');
      if (data.dating?.profile) {
        const profile = data.dating.profile;
        console.log('  name:', profile.name || 'NULL');
        console.log('  age:', profile.age || 'NULL');
        console.log('  gender:', profile.gender || 'NULL');
        console.log('  photos:', profile.photos?.length || 0, 'photos');
      }
    }
  } catch (err) {
    console.error('Error:', err.message);
  }
  process.exit(0);
}

check();
