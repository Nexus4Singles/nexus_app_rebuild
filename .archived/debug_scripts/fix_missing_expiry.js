const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({ 
  credential: admin.credential.cert(serviceAccount) 
});

const db = admin.firestore();

async function fixMissingExpiry() {
  const users = ['bajomooluwapelumi@gmail.com', 'ayomide@migo.money', 'nexus4singles@gmail.com'];
  
  for (const email of users) {
    const snap = await db.collection('users').where('email', '==', email).get();
    if (snap.docs.length > 0) {
      const user = snap.docs[0].data();
      const startDate = user.subscription?.startDate;
      
      if (startDate) {
        // Add 30 days to start date for monthly subscription
        const expiryMs = (startDate._seconds * 1000) + (30 * 24 * 60 * 60 * 1000);
        const expiryDate = new Date(expiryMs);
        
        await snap.docs[0].ref.update({
          'subExpDate': admin.firestore.Timestamp.fromDate(expiryDate),
          'entitledUser': true
        });
        
        console.log(`✅ ${email} - Set subExpDate to ${expiryDate.toDateString()}`);
      } else {
        console.log(`⚠️  ${email} - No startDate found`);
      }
    }
  }
  
  console.log('\n✅ Complete!');
  process.exit(0);
}

fixMissingExpiry().catch(e => { 
  console.error(e); 
  process.exit(1); 
});
