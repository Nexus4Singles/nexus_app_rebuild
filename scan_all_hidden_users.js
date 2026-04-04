const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function findAllHiddenUsers() {
  console.log(`\n=== COMPREHENSIVE SCAN: ALL HIDDEN/INTERNAL USERS ===\n`);

  try {
    console.log('Scanning entire users collection...\n');
    
    let allUsers = [];
    let hiddenUsers = [];
    let adminUsers = [];
    let testUsers = [];
    let internalUsers = [];
    let archivedUsers = [];

    // Get all users in batches
    let query = db.collection('users');
    let snapshot = await query.get();
    
    console.log(`Total users in system: ${snapshot.size}\n`);

    snapshot.forEach(doc => {
      const data = doc.data();
      allUsers.push(data);

      // Check for hidden flags
      if (data.isAdmin === true) {
        adminUsers.push({ email: data.email, username: data.username });
      }
      if (data.hidden === true || data.isHidden === true) {
        hiddenUsers.push({ email: data.email, username: data.username });
      }
      if (data.testAccount === true) {
        testUsers.push({ email: data.email, username: data.username });
      }
      if (data.internalAccount === true) {
        internalUsers.push({ email: data.email, username: data.username });
      }
      if (data.archived === true) {
        archivedUsers.push({ email: data.email, username: data.username });
      }
    });

    console.log('📊 HIDDEN/INTERNAL USERS BREAKDOWN:\n');
    
    console.log(`isAdmin: true (${adminUsers.length} users)`);
    adminUsers.forEach((u, i) => {
      console.log(`  ${i+1}. ${u.email || u.username}`);
    });
    console.log('');

    console.log(`hidden/isHidden: true (${hiddenUsers.length} users)`);
    hiddenUsers.forEach((u, i) => {
      console.log(`  ${i+1}. ${u.email || u.username}`);
    });
    console.log('');

    console.log(`testAccount: true (${testUsers.length} users)`);
    testUsers.forEach((u, i) => {
      console.log(`  ${i+1}. ${u.email || u.username}`);
    });
    console.log('');

    console.log(`internalAccount: true (${internalUsers.length} users)`);
    internalUsers.forEach((u, i) => {
      console.log(`  ${i+1}. ${u.email || u.username}`);
    });
    console.log('');

    console.log(`archived: true (${archivedUsers.length} users)`);
    archivedUsers.forEach((u, i) => {
      console.log(`  ${i+1}. ${u.email || u.username}`);
    });
    console.log('');

    // Summary
    const totalHidden = new Set([
      ...adminUsers.map(u => u.email),
      ...hiddenUsers.map(u => u.email),
      ...testUsers.map(u => u.email),
      ...internalUsers.map(u => u.email),
      ...archivedUsers.map(u => u.email),
    ]).size;

    console.log('─'.repeat(60));
    console.log(`\n✅ TOTAL HIDDEN/INTERNAL USERS: ${totalHidden}`);
    console.log(`   Active searchable users: ${allUsers.length - totalHidden}\n`);

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

findAllHiddenUsers();
