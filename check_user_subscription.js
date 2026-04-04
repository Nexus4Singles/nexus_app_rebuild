const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function checkUser() {
  try {
    const userId = 'nnvfiqInGrZdXKuFmXGD03Qrsoas2';
    const doc = await db.collection('users').doc(userId).get();
    
    if (!doc.exists) {
      console.log('❌ User not found');
      process.exit(1);
    }
    
    const data = doc.data();
    console.log('\n=== USER SUBSCRIPTION STATUS ===\n');
    console.log('Email:', data.email || 'NOT SET');
    console.log('Username:', data.username || 'NOT SET');
    console.log('\n--- SUBSCRIPTION V2 (NEW FORMAT) ---');
    console.log('subscription.isActive:', data.subscription?.isActive ?? 'NOT SET');
    console.log('subscription.tier:', data.subscription?.tier ?? 'NOT SET');
    console.log('subscription.expiryDate:', data.subscription?.expiryDate?.toDate?.()?.toISOString() || data.subscription?.expiryDate || 'NOT SET');
    console.log('subscription.startDate:', data.subscription?.startDate?.toDate?.()?.toISOString() || data.subscription?.startDate || 'NOT SET');
    console.log('subscription.verificationStatus:', data.subscription?.verificationStatus ?? 'NOT SET');
    console.log('subscription.revenueCatCustomerId:', data.subscription?.revenueCatCustomerId ?? 'NOT SET');
    
    console.log('\n--- LEGACY V1 FORMAT ---');
    console.log('onPremium:', data.onPremium ?? 'NOT SET');
    console.log('subExpDate:', data.subExpDate?.toDate?.()?.toISOString() || data.subExpDate || 'NOT SET');
    console.log('entitledUser:', data.entitledUser ?? 'NOT SET');
    
    console.log('\n--- OVERALL STATUS ---');
    const isActive = data.subscription?.isActive && data.subscription?.expiryDate?.toDate?.() > new Date();
    console.log('Is Premium:', isActive ? '✅ YES' : '❌ NO');
    
    if (!isActive) {
      console.log('\n⚠️  User does NOT have active subscription');
      console.log('They need to be manually awarded');
    }
    
  } catch (e) {
    console.error('Error:', e.message);
    process.exit(1);
  }
}

checkUser();
