const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkVerificationStatus() {
  try {
    // Check your specific account
    const userId = 'yjXNtVfxyraQBmD2LEvvaiGWrJo1'; // nexus4singles account
    
    const doc = await db.collection('users').doc(userId).get();
    
    if (!doc.exists) {
      console.log('❌ User not found');
      return;
    }
    
    const data = doc.data();
    const dating = data.dating || {};
    const verificationStatus = dating.verificationStatus;
    const verificationQueuedAt = dating.verificationQueuedAt;
    
    console.log('\n📋 Profile Verification Status:');
    console.log('================================');
    console.log('User ID:', userId);
    console.log('Username:', data.username || 'N/A');
    console.log('Email:', data.email || 'N/A');
    console.log('Verification Status:', verificationStatus || 'null (should be "pending")');
    console.log('Queued At:', verificationQueuedAt ? new Date(verificationQueuedAt.toDate()).toISOString() : 'null');
    console.log('Has Dating Profile:', !!dating);
    console.log('Is Admin:', data.isAdmin || false);
    
    // Check if reviewPack exists
    const reviewPack = dating.reviewPack || {};
    console.log('\n📦 Review Pack:');
    console.log('Has Review Pack:', !!dating.reviewPack);
    console.log('Photos:', reviewPack.photoUrls?.length || 0);
    console.log('Audios:', reviewPack.audioUrls?.length || 0);
    
    // If status is null, set it to pending
    if (!verificationStatus || verificationStatus === '') {
      console.log('\n⚠️  Verification status is null/empty');
      console.log('This profile should be set to "pending" to appear in admin review queue');
      
      const answer = await promptUser('\nSet verification status to "pending"? (yes/no): ');
      if (answer.toLowerCase() === 'yes') {
        await db.collection('users').doc(userId).update({
          'dating.verificationStatus': 'pending',
          'dating.verificationQueuedAt': admin.firestore.FieldValue.serverTimestamp()
        });
        console.log('✅ Status updated to "pending"');
      }
    } else if (verificationStatus === 'pending') {
      console.log('\n✅ Profile is already in "pending" status');
      console.log('It should appear in the admin review queue');
    } else {
      console.log(`\n ℹ️  Profile status is: ${verificationStatus}`);
    }
    
    // Check for all pending profiles
    console.log('\n\n📋 All Pending Profiles in Queue:');
    console.log('==================================');
    const pending = await db.collection('users')
      .where('dating.verificationStatus', '==', 'pending')
      .orderBy('dating.verificationQueuedAt', 'desc')
      .limit(10)
      .get();
      
    console.log(`Found ${pending.size} pending profile(s)\n`);
    
    pending.docs.forEach((doc, i) => {
      const data = doc.data();
      const dating = data.dating || {};
      console.log(`${i + 1}. ${data.username || data.name || 'Unknown'} (${doc.id})`);
      console.log(`   Status: ${dating.verificationStatus}`);
      console.log(`   Queued: ${dating.verificationQueuedAt ? new Date(dating.verificationQueuedAt.toDate()).toISOString() : 'N/A'}`);
      console.log(`   Admin: ${data.isAdmin ? 'Yes' : 'No'}`);
      console.log('');
    });
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

function promptUser(question) {
  const readline = require('readline');
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer);
    });
  });
}

checkVerificationStatus();
