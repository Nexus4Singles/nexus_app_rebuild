const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function hideUserFromSearch() {
  const email = 'contact@nexus4singles.com';
  
  console.log(`\n=== HIDING USER FROM SEARCH ===\n`);

  try {
    // 1. First check for invisible users
    console.log('🔍 Checking for invisible users in system...\n');
    
    const hiddenUsersSnapshot = await db
      .collection('users')
      .where('hidden', '==', true)
      .limit(3)
      .get();

    if (!hiddenUsersSnapshot.empty) {
      console.log(`Found ${hiddenUsersSnapshot.size} hidden users:\n`);
      hiddenUsersSnapshot.docs.forEach((doc, i) => {
        const data = doc.data();
        console.log(`  ${i+1}. ${data.email || data.username}`);
      });
      console.log('');
    } else {
      console.log('ℹ️  No hidden users found (empty system or no hidden flag used)\n');
    }

    // 2. Find the user to hide
    console.log('📋 Finding user to hide...');
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
    const userId = userDoc.id;
    
    console.log(`✓ User found: ${userData.username} (${email})\n`);

    // 3. Hide the user
    console.log('✅ Hiding user from search...\n');
    
    const updateData = {
      hidden: true,
      isHidden: true,
      hiddenAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
    };

    await userDoc.ref.update(updateData);

    // 4. Create audit log
    await userDoc.ref.collection('audit_log').add({
      action: 'user_hidden_from_search',
      reason: 'admin_action',
      hiddenBy: 'admin_script',
      timestamp: admin.firestore.Timestamp.now(),
      details: {
        hidden: true,
        isHidden: true,
        noLongerVisibleInSearch: true
      }
    });

    // 5. Verify
    const updatedUserDoc = await userDoc.ref.get();
    const updatedData = updatedUserDoc.data();
    
    console.log('Status:');
    console.log(`  - hidden: ${updatedData.hidden}`);
    console.log(`  - isHidden: ${updatedData.isHidden}`);
    console.log(`  - hiddenAt: ${updatedData.hiddenAt?.toDate?.() || 'now'}\n`);

    console.log(`✅ USER HIDDEN FROM SEARCH`);
    console.log(`User ${email} will no longer appear in dating search results\n`);

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

hideUserFromSearch();
