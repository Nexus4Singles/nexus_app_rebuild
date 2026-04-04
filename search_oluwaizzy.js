const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function searchUser() {
  try {
    const email = 'oluwaizzy7@gmail.com';
    
    console.log('\n=== SEARCHING FOR USER ===\n');
    console.log(`Looking for: ${email}\n`);

    // Try exact match
    console.log('1. Exact email match:');
    let query = await db.collection('users').where('email', '==', email).limit(1).get();
    if (!query.empty) {
      console.log('✅ Found!');
      const doc = query.docs[0];
      console.log(`   ID: ${doc.id}`);
      console.log(`   Email: ${doc.data().email}`);
      return;
    }
    console.log('   ❌ Not found\n');

    // Try case variations
    console.log('2. Searching with variations...');
    query = await db.collection('users').where('email', '==', email.toLowerCase()).limit(1).get();
    if (!query.empty) {
      console.log('✅ Found (lowercase)!');
      return;
    }

    // Search in username
    console.log('   Checking username...');
    query = await db.collection('users').where('username', '==', 'oluwaizzy7').limit(1).get();
    if (!query.empty) {
      console.log('✅ Found by username!');
      const doc = query.docs[0];
      console.log(`   Email: ${doc.data().email}`);
      return;
    }

    // List recent users
    console.log('\n3. Recent users (first 20):');
    const recentUsers = await db.collection('users').orderBy('createdAt', 'desc').limit(20).get();
    
    let found = false;
    for (const doc of recentUsers.docs) {
      const data = doc.data();
      if (data.email?.includes('oluwaizzy') || data.username?.includes('oluwaizzy')) {
        console.log(`✅ FOUND: ${data.email || data.username}`);
        console.log(`   ID: ${doc.id}`);
        found = true;
        break;
      }
    }

    if (!found) {
      console.log('   No similar users found\n');
      console.log('Users with "oluwai" prefix:');
      for (const doc of recentUsers.docs) {
        const data = doc.data();
        if (data.email?.includes('oluwai')) {
          console.log(`   - ${data.email}`);
        }
      }
    }

  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

searchUser();
