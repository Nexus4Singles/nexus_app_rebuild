const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function findAllAdminUsers() {
  console.log(`\n=== FINDING ALL isAdmin: true USERS ===\n`);

  try {
    const snapshot = await db
      .collection('users')
      .where('isAdmin', '==', true)
      .get();

    console.log(`Found ${snapshot.size} admin users:\n`);

    snapshot.forEach((doc, i) => {
      const data = doc.data();
      console.log(`${i+1}. ${data.email || data.username}`);
      console.log(`   ID: ${doc.id}`);
      console.log(`   Username: ${data.username}`);
      console.log(`   isAdmin: ${data.isAdmin}`);
      console.log('');
    });

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

findAllAdminUsers();
