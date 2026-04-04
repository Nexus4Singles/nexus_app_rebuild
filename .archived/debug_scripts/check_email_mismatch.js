const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

(async () => {
  const userId = 'vesZztygrfQ2PhPlfig9SabyY1t1';
  
  console.log('\n🔍 Checking email mismatch for user: ' + userId);
  
  // Check Firebase Auth
  const auth = admin.auth();
  let authUser;
  try {
    authUser = await auth.getUser(userId);
    console.log('\n📧 Firebase Auth Email:');
    console.log('   Email: ' + authUser.email);
    console.log('   Email Verified: ' + authUser.emailVerified);
    console.log('   Created: ' + new Date(authUser.metadata.creationTime).toISOString());
    console.log('   Last Sign-in: ' + (authUser.metadata.lastSignInTime ? new Date(authUser.metadata.lastSignInTime).toISOString() : 'N/A'));
  } catch (e) {
    console.log('❌ Firebase Auth user not found: ' + e.message);
  }
  
  // Check Firestore
  const db = admin.firestore();
  const doc = await db.collection('users').doc(userId).get();
  if (doc.exists) {
    const data = doc.data();
    console.log('\n📋 Firestore Document Email:');
    console.log('   Email: ' + data.email);
    console.log('   Created At: ' + (data.createdAt?.toDate?.() || data.createdAt || 'N/A'));
    console.log('   Updated At: ' + (data.updatedAt?.toDate?.() || data.updatedAt || 'N/A'));
  }
  
  // Compare
  if (authUser && doc.exists) {
    const authEmail = authUser.email?.toLowerCase() || '';
    const firestoreEmail = doc.data().email?.toLowerCase() || '';
    console.log('\n⚖️  COMPARISON:');
    console.log('   Auth Email: ' + authEmail);
    console.log('   Firestore Email: ' + firestoreEmail);
    
    if (authEmail === firestoreEmail) {
      console.log('   ✅ MATCH - Emails are the same');
    } else {
      console.log('   ❌ MISMATCH - Emails are different!');
      console.log('\n💡 This suggests:');
      console.log('   1. User signed up with: ' + authEmail);
      console.log('   2. But Firestore was updated with: ' + firestoreEmail);
    }
  }
  
  console.log('\n');
})();
