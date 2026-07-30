const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const userId = 'sT7oObb7hUNHvU49oWpvmVFuCu53';

async function analyze() {
  try {
    // Check if there's any audit/history data
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const data = userDoc.data();

    console.log('\n🔍 Checking for signs of incomplete onboarding:');
    
    console.log('\n1️⃣ Dating profile status:');
    console.log('   dating.profileCompleted:', data?.dating?.profileCompleted);
    console.log('   dating.verificationStatus:', data?.dating?.verificationStatus);
    console.log('   dating.createdAt:', data?.dating?.createdAt);
    
    console.log('\n2️⃣ Core profile fields:');
    console.log('   age:', data?.age);
    console.log('   profession:', data?.profession);
    console.log('   educationLevel:', data?.educationLevel);
    console.log('   hobbies:', data?.hobbies);
    console.log('   desiredQualities:', data?.desiredQualities);

    console.log('\n3️⃣ Photos/Audio:');
    console.log('   photos count:', data?.photos?.length || 0);
    console.log('   audioPrompts count:', data?.audioPrompts?.length || 0);
    
    console.log('\n4️⃣ Checking timestamp sequence:');
    console.log('   createdAt:', data?.createdAt);
    console.log('   updatedAt:', data?.updatedAt);
    console.log('   dating.createdAt:', data?.dating?.createdAt);
    console.log('   dating.verificationQueuedAt:', data?.dating?.verificationQueuedAt);

    // Try to see if there are any activity logs
    console.log('\n5️⃣ Checking for logs in Firestore:');
    const logs = await admin.firestore().collection('users').doc(userId).collection('logs').limit(5).get();
    if (!logs.empty) {
      console.log('   Found activity logs:');
      logs.docs.forEach(doc => {
        const logData = doc.data();
        console.log(`     - ${logData.action} at ${logData.timestamp}`);
      });
    } else {
      console.log('   No activity logs collection found');
    }

  } catch (err) {
    console.error('Error:', err.message);
  }
  process.exit(0);
}

analyze();
