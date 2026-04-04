const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();
const auth = admin.auth();

async function checkUserComprehensive() {
  try {
    const userId = 'nnvfiqInGrZdXKuFmXGD03Qrsoas2';
    
    console.log('\n=== COMPREHENSIVE USER CHECK ===\n');
    console.log(`Checking user ID: ${userId}\n`);
    
    // Check in Firebase Auth
    console.log('1️⃣  FIREBASE AUTH:');
    try {
      const user = await auth.getUser(userId);
      console.log('   ✅ Found in Auth');
      console.log(`   Email: ${user.email}`);
      console.log(`   Created: ${user.metadata.creationTime}`);
    } catch (e) {
      console.log('   ❌ NOT in Firebase Auth');
    }
    
    // Check in Firestore users collection
    console.log('\n2️⃣  FIRESTORE users/{userId}:');
    const userDoc = await db.collection('users').doc(userId).get();
    if (userDoc.exists) {
      const data = userDoc.data();
      console.log('   ✅ Found in Firestore');
      console.log(`   Email: ${data.email || 'NOT SET'}`);
      console.log(`   Created: ${data.createdAt?.toDate?.()?.toISOString() || 'NOT SET'}`);
    } else {
      console.log('   ❌ NOT in Firestore');
    }
    
    // Check in recent subscriptions (by searching all users)
    console.log('\n3️⃣  CHECKING RECENT SUBSCRIPTIONS:');
    const recentUsers = await db.collection('users')
      .where('subscription.isActive', '==', true)
      .orderBy('subscription.expiryDate', 'desc')
      .limit(5)
      .get();
    
    console.log(`   Found ${recentUsers.size} recent premium users`);
    let foundMatch = false;
    
    for (const doc of recentUsers.docs) {
      if (doc.id === userId) {
        console.log('   ✅ User found with active subscription!');
        const data = doc.data();
        console.log(`      Tier: ${data.subscription.tier}`);
        console.log(`      Expires: ${data.subscription.expiryDate?.toDate?.()?.toISOString()}`);
        foundMatch = true;
        break;
      }
    }
    
    if (!foundMatch) {
      console.log('   ❌ User NOT in recent premium list');
    }
    
    console.log('\n' + '='.repeat(60));
    console.log('VERDICT:');
    console.log('='.repeat(60));
    
    if (!userDoc.exists) {
      console.log('\n⚠️  User document does NOT exist in Firestore');
      console.log('\nPossible reasons:');
      console.log('1. User ID is incorrect');
      console.log('2. User just created but hasn\'t opened app yet');
      console.log('3. User in different project/database');
      console.log('\nNEXT STEP: Please verify the user ID and provide the email instead');
    } else {
      const sub = userDoc.data().subscription;
      if (!sub || !sub.isActive) {
        console.log('\n❌ NO SUBSCRIPTION FOUND');
        console.log('User needs manual subscription award');
      } else {
        console.log('\n✅ Subscription is active');
      }
    }
    
  } catch (e) {
    console.error('Unexpected error:', e.message);
    process.exit(1);
  }
}

checkUserComprehensive();
