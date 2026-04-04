const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function check() {
  const email = 'princessosebi@yahoo.com';
  
  const usersSnapshot = await db
    .collection('users')
    .where('email', '==', email)
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    console.log('User not found');
    process.exit(1);
  }

  const userDoc = usersSnapshot.docs[0];
  const userData = userDoc.data();
  
  console.log('\n=== PRINCESSOSEBI FULL USER DOCUMENT ===\n');
  console.log(JSON.stringify(userData, null, 2));
}

check().catch(console.error);
