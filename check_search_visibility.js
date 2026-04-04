const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function checkSearchVisibility() {
  const email = 'contact@nexus4singles.com';
  
  console.log(`\n=== CHECKING SEARCH VISIBILITY ===\n`);
  console.log(`Email: ${email}\n`);

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
    
    console.log(`User: ${userData.username || userData.name} (${userData.email})\n`);

    // Check relevant fields that affect search visibility
    console.log('🔍 Search Visibility Flags:\n');
    
    const hiddenFlags = {
      'hidden': userData.hidden,
      'isHidden': userData.isHidden,
      'visible': userData.visible,
      'searchable': userData.searchable,
      'blockedFromSearch': userData.blockedFromSearch,
      'excludeFromSearch': userData.excludeFromSearch,
      'archived': userData.archived,
      'deleted': userData.deleted,
      'suspended': userData.suspended,
      'banned': userData.banned,
      'showInSearch': userData.showInSearch,
      'isVisible': userData.isVisible,
    };

    let isHidden = false;
    Object.entries(hiddenFlags).forEach(([key, value]) => {
      console.log(`  ${key}: ${value !== undefined ? value : 'not set'}`);
      if ((key.includes('hidden') || key.includes('hidden') || key === 'archived' || key === 'deleted' || key === 'suspended' || key === 'banned') && value === true) {
        isHidden = true;
      }
      if ((key === 'visible' || key === 'searchable' || key === 'showInSearch' || key === 'isVisible') && value === false) {
        isHidden = true;
      }
    });

    console.log('\n' + '─'.repeat(50) + '\n');
    
    if (isHidden) {
      console.log('✅ YES - User is HIDDEN from search results');
      console.log('   This user will NOT appear in dating search\n');
    } else {
      console.log('⚠️  NO - User is VISIBLE in search results');
      console.log('   This user WILL appear in dating search\n');
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

checkSearchVisibility();
