#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

(async () => {
  try {
    const snapshot = await db.collection('users').where('email', '==', '20funmigloria@gmail.com').limit(1).get();
    const userData = snapshot.docs[0].data();
    
    console.log('✅ VERIFICATION - Current subscription status:');
    console.log('');
    console.log('👤 User:', userData.name || userData.username);
    console.log('📧 Email:', userData.email);
    console.log('');
    console.log('💳 Subscription Status:');
    console.log('   isActive:', userData.subscription.isActive);
    console.log('   tier:', userData.subscription.tier);
    console.log('   startDate:', userData.subscription.startDate?.toDate?.().toLocaleDateString());
    console.log('   expiryDate:', userData.subscription.expiryDate?.toDate?.().toLocaleDateString());
    console.log('   autoRenew:', userData.subscription.autoRenew);
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
})();
