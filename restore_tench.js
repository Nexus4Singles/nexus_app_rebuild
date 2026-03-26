const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

(async () => {
  const db = admin.firestore();
  const userId = 'vesZztygrfQ2PhPlfig9SabyY1t1';
  const doc = await db.collection('users').doc(userId).get();
  
  if (!doc.exists) {
    console.log('❌ User not found');
    process.exit(1);
  }
  
  const data = doc.data();
  console.log('✅ Found user: ' + userId);
  console.log('   Email: ' + data.email);
  console.log('   Username: ' + (data.username || data.name));
  
  const dating = data.dating || {};
  console.log('\n📋 Current Status:');
  console.log('   isActive: ' + dating.isActive);
  console.log('   profileCompleted: ' + dating.profileCompleted);
  console.log('   archivedAt: ' + (dating.archivedAt?.toDate?.() || dating.archivedAt || 'N/A'));
  
  if (dating.isActive !== false) {
    console.log('\n⚠️  Profile is not archived. No action needed.\n');
    process.exit(0);
  }
  
  console.log('\n🔄 Restoring profile...');
  const updateData = {
    'dating.profileCompleted': true,
    'dating.isActive': true,
    'dating.optIn': true,
    'dating.restoredAt': admin.firestore.FieldValue.serverTimestamp(),
  };
  updateData['dating.archivedAt'] = admin.firestore.FieldValue.delete();
  
  await db.collection('users').doc(userId).update(updateData);
  
  console.log('✅ Profile successfully restored!\n');
  console.log('   Profile will now appear in dating search results');
  console.log('   User can see their profile in the app immediately\n');
  process.exit(0);
})();
