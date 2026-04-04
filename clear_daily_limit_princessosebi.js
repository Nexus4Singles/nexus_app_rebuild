const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function fix() {
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
  const userId = userDoc.id;
  
  console.log('Clearing daily limit for user:', userId);
  
  // Clear the daily limit tracking so she can see unlimited profiles now
  await userDoc.ref.update({
    'dating.dailyLimitFirstHit': admin.firestore.FieldValue.delete(),
    'dating.shownProfileIds': admin.firestore.FieldValue.delete(),
    'dating.clientClearedAt': admin.firestore.FieldValue.delete(),
    'dating.lastResetAt': admin.firestore.Timestamp.now(),
  });
  
  console.log('✅ Daily limit cleared for princessosebi');
  console.log('She can now access unlimited profiles with her active subscription');
}

fix().catch(console.error);
