const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();
const userId = 'IMBEnQigtsbRYghhvdVfbSKmqKh1';

(async () => {
  try {
    const subDoc = await db.collection('users').doc(userId).collection('subscription').doc('current').get();
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (subDoc.exists) {
      const sub = subDoc.data();
      const user = userDoc.data();
      console.log('\n✅ SUBSCRIPTION ACTIVATED SUCCESSFULLY\n');
      console.log(`Email: ${user.email}`);
      console.log(`Tier: ${sub.tier}`);
      console.log(`Active: ${sub.isActive}`);
      console.log(`Expires: ${sub.expiryDate.toDate()}`);
      console.log(`Verified: ${sub.verificationStatus}`);
      console.log(`onPremium: ${user.onPremium}`);
      console.log(`entitledUser: ${user.entitledUser}\n`);
    } else {
      console.log('❌ Subscription not found');
    }
    process.exit(0);
  } catch (e) {
    console.error('Error:', e.message);
    process.exit(1);
  }
})();
