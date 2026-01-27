/**
 * Fix ALL pending profiles that are missing verificationQueuedAt or reviewPack
 * This ensures all pending profiles appear in the admin review queue
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('../serviceAccount.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function fixAllPendingProfiles() {
  console.log('🔍 Searching for pending profiles...\n');
  
  try {
    // Find all users with dating.verificationStatus = 'pending'
    const usersRef = db.collection('users');
    const snapshot = await usersRef.where('dating.verificationStatus', '==', 'pending').get();
    
    console.log(`Found ${snapshot.size} profile(s) with verification status = pending\n`);
    
    let fixedCount = 0;
    let alreadyFixedCount = 0;
    
    for (const doc of snapshot.docs) {
      const userId = doc.id;
      const data = doc.data();
      const dating = data.dating || {};
      
      // Check if already has required fields
      const hasQueuedAt = dating.verificationQueuedAt != null;
      const hasReviewPack = dating.reviewPack != null;
      
      if (hasQueuedAt && hasReviewPack) {
        console.log(`✅ ${data.name || 'Unknown'} (${userId}) - Already fixed`);
        alreadyFixedCount++;
        continue;
      }
      
      console.log(`🔧 Fixing ${data.name || 'Unknown'} (${userId})...`);
      
      // Collect photos
      const photoUrls = [];
      if (dating.photos && Array.isArray(dating.photos)) {
        photoUrls.push(...dating.photos.filter(url => url));
      }
      
      // Collect audio
      const audioUrls = [];
      const audio1 = data.audio?.audio1Url || dating.audio1Url;
      const audio2 = data.audio?.audio2Url || dating.audio2Url;
      const audio3 = data.audio?.audio3Url || dating.audio3Url;
      
      if (audio1) audioUrls.push(audio1);
      if (audio2) audioUrls.push(audio2);
      if (audio3) audioUrls.push(audio3);
      
      // Get gender and relationship status
      const gender = data.nexus2?.gender || data.gender || null;
      const relationshipStatus = data.nexus2?.relationshipStatus || data.relationshipStatus || null;
      
      // Prepare update
      const updates = {
        'dating.verificationQueuedAt': admin.firestore.FieldValue.serverTimestamp(),
        'dating.reviewPack': {
          photoUrls,
          audioUrls,
          submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      };
      
      // Mirror gender and relationship status if available
      if (gender) {
        updates['dating.gender'] = gender;
      }
      if (relationshipStatus) {
        updates['dating.relationshipStatus'] = relationshipStatus;
      }
      
      // Apply update
      await usersRef.doc(userId).update(updates);
      
      console.log(`   📸 Photos: ${photoUrls.length}`);
      console.log(`   🎤 Audio: ${audioUrls.length}`);
      console.log(`   ✅ Fixed!\n`);
      
      fixedCount++;
    }
    
    console.log('\n' + '='.repeat(60));
    console.log(`📊 Summary:`);
    console.log(`   Total pending profiles: ${snapshot.size}`);
    console.log(`   Already fixed: ${alreadyFixedCount}`);
    console.log(`   Newly fixed: ${fixedCount}`);
    console.log('='.repeat(60));
    
    // Verify the fix by querying the admin queue
    console.log('\n🔍 Verifying admin queue...');
    const queueSnapshot = await usersRef
      .where('dating.verificationStatus', '==', 'pending')
      .orderBy('dating.verificationQueuedAt', 'desc')
      .limit(50)
      .get();
    
    console.log(`\n✅ Found ${queueSnapshot.size} profile(s) in queue (with verificationQueuedAt):`);
    queueSnapshot.forEach((doc) => {
      const data = doc.data();
      const dating = data.dating || {};
      const reviewPack = dating.reviewPack || {};
      const queuedAt = dating.verificationQueuedAt?.toDate().toISOString() || 'N/A';
      
      console.log(`   ${queueSnapshot.docs.indexOf(doc) + 1}. ${data.name || 'Unknown'} (${doc.id})`);
      console.log(`      Photos: ${reviewPack.photoUrls?.length || 0}, Audio: ${reviewPack.audioUrls?.length || 0}`);
      console.log(`      Queued: ${queuedAt}`);
    });
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

fixAllPendingProfiles();
