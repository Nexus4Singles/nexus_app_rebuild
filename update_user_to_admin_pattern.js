const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function updateHiddenUserToMatchPattern() {
  const email = 'contact@nexus4singles.com';
  
  console.log(`\n=== UPDATING USER TO MATCH HIDDEN PATTERN ===\n`);

  try {
    const usersSnapshot = await db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.error(`❌ User not found`);
      process.exit(1);
    }

    const userDoc = usersSnapshot.docs[0];
    const userData = userDoc.data();
    
    console.log(`User: ${userData.username} (${email})\n`);

    // Update to use isAdmin: true pattern like other Nexus accounts
    const updateData = {
      isAdmin: true,
      updatedAt: admin.firestore.Timestamp.now(),
    };

    await userDoc.ref.update(updateData);
    console.log('✅ Updated: isAdmin set to true');
    console.log('   User now follows same hidden pattern as nexus4singles@gmail.com\n');

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

updateHiddenUserToMatchPattern();
