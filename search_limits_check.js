const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function check() {
  const usersSnapshot = await db
    .collection('users')
    .where('email', '==', 'princessosebi@yahoo.com')
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    console.log('User not found');
    process.exit(1);
  }

  const userData = usersSnapshot.docs[0].data();
  
  console.log('\n=== DAILY SEARCH LIMITS ===');
  console.log('dailySearchLimit:', userData.dailySearchLimit);
  console.log('dailySearchUsed:', userData.dailySearchUsed);
  
  console.log('\n=== DATING SEARCH LIMITS ===');
  console.log('dating.dailySearchLimit:', userData.dating?.dailySearchLimit);
  console.log('dating.dailySearchUsed:', userData.dating?.dailySearchUsed);
  console.log('dating.dailySearchResetAt:', userData.dating?.dailySearchResetAt?.toDate?.());
  
  console.log('\n=== SUBSCRIPTION ===');
  console.log('onPremium:', userData.onPremium);
  console.log('subscription.isActive:', userData.subscription?.isActive);
  console.log('subscription.tier:', userData.subscription?.tier);
  console.log('subscription.expiryDate:', userData.subscription?.expiryDate?.toDate?.());
}

check().catch(console.error);
