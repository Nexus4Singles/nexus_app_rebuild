const admin = require('firebase-admin');
const s = require('./serviceAccount.json');
admin.initializeApp({ credential: admin.credential.cert(s) });
const db = admin.firestore();

(async () => {
  // Check existing coaches
  const coaches = await db.collection('coaches').get();
  console.log('\n=== EXISTING COACHES ===');
  console.log('Count:', coaches.size);
  coaches.forEach(d => {
    const c = d.data();
    console.log('\nID:', d.id);
    console.log('  name:', c.name);
    console.log('  userId:', c.userId);
    console.log('  isActive:', c.isActive);
    console.log('  sessionTypes:', JSON.stringify(c.sessionTypes));
    console.log('  email:', c.email);
  });

  // Find nexus4singles user
  const usersSnap = await db.collection('users').where('email', '==', 'nexus4singles@gmail.com').get();
  console.log('\n=== nexus4singles@gmail.com USER ===');
  if (usersSnap.empty) {
    console.log('User not found in Firestore users collection');
  } else {
    usersSnap.forEach(d => {
      const u = d.data();
      console.log('UID:', d.id);
      console.log('name:', u.name || u.displayName);
      console.log('email:', u.email);
    });
  }
})();
