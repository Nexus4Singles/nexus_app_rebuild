const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function searchUser() {
  try {
    const userId = 'nvfiqInGrZdXKuFmXGD03Qrsoas2';
    const email = 'esthercjude@gmail.com';
    
    console.log('\n=== SEARCHING FOR USER ===\n');
    console.log(`User ID: ${userId}`);
    console.log(`Email: ${email}\n`);
    
    // Try user ID
    console.log('1️⃣  Direct user ID lookup:');
    const userDocId = await db.collection('users').doc(userId).get();
    if (userDocId.exists) {
      const data = userDocId.data();
      console.log('   ✅ FOUND by ID!');
      console.log(`   Email: ${data.email}`);
      printSubscriptionInfo(data, userId);
      return;
    }
    console.log('   ❌ Not found by ID');
    
    // Try searching by email
    console.log('\n2️⃣  Search by email:');
    const emailQuery = await db.collection('users').where('email', '==', email).limit(1).get();
    
    if (!emailQuery.empty) {
      const doc = emailQuery.docs[0];
      console.log('   ✅ FOUND by email!');
      console.log(`   User ID: ${doc.id}`);
      printSubscriptionInfo(doc.data(), doc.id);
      return;
    }
    console.log('   ❌ Not found by email');
    
    console.log('\n⚠️  User not found by either ID or email');
    
  } catch (e) {
    console.error('\n❌ Error:', e.message);
    process.exit(1);
  }
}

function printSubscriptionInfo(data, userId) {
  console.log('\n   --- SUBSCRIPTION STATUS ---');
  
  const sub = data.subscription;
  const isActive = sub?.isActive && sub?.expiryDate?.toDate?.() > new Date();
  
  console.log(`   Subscription Active: ${isActive ? '✅ YES' : '❌ NO'}`);
  
  if (sub) {
    console.log(`   Tier: ${sub.tier || 'NOT SET'}`);
    console.log(`   Expiry: ${sub.expiryDate?.toDate?.()?.toISOString() || 'NOT SET'}`);
    console.log(`   Start Date: ${sub.startDate?.toDate?.()?.toISOString() || 'NOT SET'}`);
    console.log(`   Verification: ${sub.verificationStatus || 'NOT SET'}`);
  }
  
  console.log(`   onPremium (V1): ${data.onPremium ? 'YES' : 'NO'}`);
  
  if (!isActive) {
    console.log('\n   ⚠️  NO ACTIVE SUBSCRIPTION - needs manual award');
  }
}

searchUser();
