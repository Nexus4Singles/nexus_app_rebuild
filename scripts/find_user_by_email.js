const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require(path.join(__dirname, '../serviceAccount.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function findUserByEmail(email) {
  try {
    const snapshot = await db.collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();
    
    if (snapshot.empty) {
      console.log(`❌ User not found with email: ${email}`);
      process.exit(1);
    }
    
    const userDoc = snapshot.docs[0];
    const uid = userDoc.id;
    const userData = userDoc.data();
    
    console.log(`✅ Found user: ${uid}`);
    console.log(`   Email: ${userData.email}`);
    console.log(`   Username: ${userData.username || userData.displayName || 'N/A'}`);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
  process.exit(0);
}

findUserByEmail(process.argv[2]);
