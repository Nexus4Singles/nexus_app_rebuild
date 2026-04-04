const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function checkHiddenUsersDetails() {
  console.log(`\n=== CHECKING HIDDEN USERS VISIBILITY CONFIGURATION ===\n`);

  try {
    const hiddenEmails = [
      'nexus4singles@gmail.com',
      'nexusgodlydatingapp@gmail.com',
    ];

    for (const email of hiddenEmails) {
      const snapshot = await db
        .collection('users')
        .where('email', '==', email)
        .limit(1)
        .get();

      if (!snapshot.empty) {
        const userData = snapshot.docs[0].data();
        console.log(`📧 ${email}`);
        console.log(`   Username: ${userData.username}\n`);
        console.log('   Visibility-related fields:');
        
        const allKeys = Object.keys(userData);
        const visibilityKeys = allKeys.filter(k => 
          k.toLowerCase().includes('hidden') || 
          k.toLowerCase().includes('visible') || 
          k.toLowerCase().includes('search') ||
          k.toLowerCase().includes('archive') ||
          k.toLowerCase().includes('block') ||
          k.toLowerCase().includes('admin') ||
          k.toLowerCase().includes('test') ||
          k.toLowerCase().includes('internal') ||
          k.toLowerCase().includes('deleted') ||
          k.toLowerCase().includes('active') ||
          k.toLowerCase().includes('status')
        );

        if (visibilityKeys.length > 0) {
          visibilityKeys.forEach(key => {
            console.log(`   - ${key}: ${userData[key]}`);
          });
        } else {
          console.log('   (No typical visibility fields found)');
          console.log('\n   All fields:');
          allKeys.forEach(key => {
            if (!['password', 'token', 'salt'].includes(key.toLowerCase())) {
              const value = userData[key];
              if (value !== null && value !== undefined && typeof value !== 'object') {
                console.log(`   - ${key}: ${value}`);
              }
            }
          });
        }
        console.log('');
      }
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

checkHiddenUsersDetails();
