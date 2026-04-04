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
  
  console.log('\n=== USER SUBSCRIPTION STATUS ===');
  console.log(`Username: ${userData.username || userData.name}`);
  console.log(`\nV2 Subscription:`, userData.subscription || 'NONE');
  console.log(`\nV1 Fields:`);
  console.log(`  - onPremium: ${userData.onPremium}`);
  console.log(`  - subExpDate: ${userData.subExpDate?.toDate?.() || userData.subExpDate}`);
  console.log(`  - entitledUser: ${userData.entitledUser}`);
  
  const subSnapshot = await userDoc.ref.collection('subscription').doc('current').get();
  console.log(`\nsubscription/current subcollection:`, subSnapshot.data() || 'NONE');
}

check().catch(console.error);
