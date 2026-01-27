const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixVerificationQueue() {
  try {
    const userId = 'yjXNtVfxyraQBmD2LEvvaiGWrJo1'; // nexus4singles
    
    const doc = await db.collection('users').doc(userId).get();
    
    if (!doc.exists) {
      console.log('❌ User not found');
      return;
    }
    
    const data = doc.data();
    const dating = data.dating || {};
    
    console.log('\n🔧 Fixing Verification Queue Entry');
    console.log('===================================\n');
    
    // Collect photos from the profile
    const photos = data.photos || [];
    const datingPhotos = dating.photos || [];
    const allPhotos = [...new Set([...photos, ...datingPhotos])].filter(p => p && p.trim());
    
    // Collect audio prompts
    const audioPrompts = data.audioPrompts || [];
    const datingAudio = dating.audioPrompts || [];
    const allAudio = [...new Set([...audioPrompts, ...datingAudio])].filter(a => a && a.trim());
    
    console.log('📸 Found Photos:', allPhotos.length);
    console.log('🎤 Found Audio:', allAudio.length);
    
    // Build reviewPack
    const reviewPack = {
      photoUrls: allPhotos.slice(0, 4), // Max 4 photos
      audioUrls: allAudio.slice(0, 3),  // Max 3 audios
      submittedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Update the profile
    await db.collection('users').doc(userId).update({
      'dating.verificationStatus': 'pending',
      'dating.verificationQueuedAt': admin.firestore.FieldValue.serverTimestamp(),
      'dating.reviewPack': reviewPack,
      'dating.gender': data.gender || null,
      'dating.relationshipStatus': data.nexus2?.relationshipStatus || null
    });
    
    console.log('\n✅ Profile updated successfully!');
    console.log('\nChanges made:');
    console.log('- Set verificationStatus to "pending"');
    console.log('- Added verificationQueuedAt timestamp');
    console.log('- Created reviewPack with photos and audio');
    console.log('- Mirrored gender and relationship status');
    
    console.log('\n📋 Your profile should now appear in the admin review queue');
    console.log('   (But you won\'t see it since admins can\'t review themselves)');
    
    // Verify the fix
    console.log('\n🔍 Verifying fix...');
    const pending = await db.collection('users')
      .where('dating.verificationStatus', '==', 'pending')
      .orderBy('dating.verificationQueuedAt', 'desc')
      .limit(10)
      .get();
    
    console.log(`\n✅ Found ${pending.size} pending profile(s) in queue\n`);
    
    pending.docs.forEach((doc, i) => {
      const data = doc.data();
      const dating = data.dating || {};
      const reviewPack = dating.reviewPack || {};
      console.log(`${i + 1}. ${data.username || data.name || 'Unknown'} (${doc.id})`);
      console.log(`   Photos: ${reviewPack.photoUrls?.length || 0}, Audio: ${reviewPack.audioUrls?.length || 0}`);
      console.log(`   Queued: ${dating.verificationQueuedAt ? new Date(dating.verificationQueuedAt.toDate()).toISOString() : 'N/A'}`);
      console.log('');
    });
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

fixVerificationQueue();
