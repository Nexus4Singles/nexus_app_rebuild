const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function activate() {
  const email = 'yemosokokatugwa@gmail.com';
  
  const snap = await db.collection('users').where('email', '==', email).get();
  if (snap.empty) {
    console.log('User not found');
    return;
  }

  const userId = snap.docs[0].id;
  const expiryDate = new Date();
  expiryDate.setDate(expiryDate.getDate() + 30);

  await db.collection('users').doc(userId).update({
    subscription: {
      isActive: true,
      tier: 'monthly_premium',
      startDate: admin.firestore.FieldValue.serverTimestamp(),
      expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
      validatedBy: 'flutterwave_manual_activation',
    },
    onPremium: true,
    subExpDate: admin.firestore.Timestamp.fromDate(expiryDate),
    entitledUser: true,
  });

  console.log('✅ Activated:', email);
  console.log('   Expires:', expiryDate.toISOString());
}

activate().then(() => process.exit(0)).catch(e => {
  console.error('Error:', e.message);
  process.exit(1);
});
