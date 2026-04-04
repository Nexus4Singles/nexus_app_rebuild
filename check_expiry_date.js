const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

(async () => {
  const doc = await db.collection('users').doc('S4wBUswb6nYF3rJNwBPTMGMk0vy2').get();
  const d = doc.data();
  const exp = d.subscription?.expiryDate;
  
  console.log('\n=== CHECKING STORED VALUE ===\n');
  console.log('Raw expiry object:', exp);
  console.log('ISO String:', exp?.toDate?.()?.toISOString?.());
  console.log('Seconds (Unix):', exp?.seconds);
  
  const date = exp?.toDate?.();
  console.log('\nFormatted:');
  console.log('UTC String:', date?.toUTCString?.());
  console.log('Local String:', date?.toString?.());
  
  const day = date?.getUTCDate?.();
  const month = date?.getUTCMonth?.() + 1;
  const year = date?.getUTCFullYear?.();
  console.log('\nUTC Date parts:');
  console.log(`Date: ${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`);
})();
