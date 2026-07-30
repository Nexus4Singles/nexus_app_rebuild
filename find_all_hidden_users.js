const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function findHiddenUsers() {
  console.log(`\n=== FINDING HIDDEN USERS ===\n`);

  try {
    // 1. Check for specific known hidden users
    console.log('🔍 Searching for known hidden users...\n');
    
    const knownEmails = [
      'nexus4singles@gmail.com',
      'nexusgodlydatingapp@gmail.com',
      'contact@nexus4christians.com'
    ];

    let hiddenUsersFound = [];

    for (const email of knownEmails) {
      const snapshot = await db
        .collection('users')
        .where('email', '==', email)
        .limit(1)
        .get();

      if (!snapshot.empty) {
        const userData = snapshot.docs[0].data();
        hiddenUsersFound.push({
          email: email,
          username: userData.username,
          hidden: userData.hidden,
          isHidden: userData.isHidden,
          visible: userData.visible,
          searchable: userData.searchable,
          archived: userData.archived,
          deleted: userData.deleted,
          blocked: userData.blocked,
          showInSearch: userData.showInSearch,
          internalAccount: userData.internalAccount,
          testAccount: userData.testAccount,
          adminAccount: userData.adminAccount,
        });
      }
    }

    if (hiddenUsersFound.length > 0) {
      console.log('Found users:');
      hiddenUsersFound.forEach((user, i) => {
        console.log(`\n${i+1}. ${user.email}`);
        console.log(`   Username: ${user.username}`);
        Object.entries(user).forEach(([key, value]) => {
          if (key !== 'email' && key !== 'username' && value !== undefined && value !== null && value !== false) {
            console.log(`   ${key}: ${value}`);
          }
        });
      });
      console.log('');
    }

    // 2. Search for any users with hidden-related flags
    console.log('\n📊 Scanning all users for visibility flags...\n');
    
    const allUsersSnapshot = await db.collection('users').get();
    
    let usersWithFlags = [];
    
    allUsersSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const hasHiddenFlag = data.hidden === true || 
                           data.isHidden === true || 
                           data.visible === false || 
                           data.searchable === false ||
                           data.showInSearch === false ||
                           data.archived === true ||
                           data.deleted === true ||
                           data.internalAccount === true ||
                           data.testAccount === true ||
                           data.adminAccount === true ||
                           data.blockedFromSearch === true;
      
      if (hasHiddenFlag) {
        const flags = [];
        if (data.hidden === true) flags.push('hidden');
        if (data.isHidden === true) flags.push('isHidden');
        if (data.visible === false) flags.push('visible=false');
        if (data.searchable === false) flags.push('searchable=false');
        if (data.showInSearch === false) flags.push('showInSearch=false');
        if (data.archived === true) flags.push('archived');
        if (data.deleted === true) flags.push('deleted');
        if (data.internalAccount === true) flags.push('internalAccount');
        if (data.testAccount === true) flags.push('testAccount');
        if (data.adminAccount === true) flags.push('adminAccount');
        if (data.blockedFromSearch === true) flags.push('blockedFromSearch');
        
        usersWithFlags.push({
          email: data.email,
          username: data.username,
          flags: flags
        });
      }
    });

    if (usersWithFlags.length > 0) {
      console.log(`Found ${usersWithFlags.length} users with visibility restrictions:\n`);
      usersWithFlags.forEach((user, i) => {
        console.log(`${i+1}. ${user.email || user.username}`);
        console.log(`   Flags: ${user.flags.join(', ')}`);
      });
      console.log('');
    } else {
      console.log('No users found with visibility restriction flags\n');
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

findHiddenUsers();
