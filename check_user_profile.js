const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating-prod.firebaseio.com'
});

const userId = 'sT7oObb7hUNHvU49oWpvmVFuCu53';

async function checkUser() {
  try {
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.log('❌ User not found');
      process.exit(1);
    }

    const data = userDoc.data();
    console.log('\n📋 Full User Document:');
    console.log(JSON.stringify(data, null, 2));

    console.log('\n🔍 Key Fields Status:');
    console.log(`  age: ${data.age ?? 'NULL'}`);
    console.log(`  profession: ${data.profession ?? 'NULL'}`);
    console.log(`  educationLevel: ${data.educationLevel ?? 'NULL'}`);
    console.log(`  gender: ${data.gender ?? 'NULL'}`);
    console.log(`  name: ${data.name ?? 'NULL'}`);
    
    console.log('\n📍 Nested Paths:');
    if (data.dating?.profile) {
      console.log('  dating.profile:', JSON.stringify(data.dating.profile, null, 2));
    } else {
      console.log('  dating.profile: NOT FOUND');
    }

    if (data.nexus2?.profile) {
      console.log('  nexus2.profile:', JSON.stringify(data.nexus2.profile, null, 2));
    } else {
      console.log('  nexus2.profile: NOT FOUND');
    }

  } catch (error) {
    console.error('Error:', error);
  }
  
  process.exit(0);
}

checkUser();
