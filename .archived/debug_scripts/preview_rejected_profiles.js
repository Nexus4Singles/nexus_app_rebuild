#!/usr/bin/env node

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

(async () => {
  const db = admin.firestore();

  console.log('\n🔍 Querying all rejected dating profiles...\n');

  const snapshot = await db
    .collection('users')
    .where('dating.verificationStatus', '==', 'rejected')
    .get();

  if (snapshot.empty) {
    console.log('✅ No rejected profiles found.\n');
    process.exit(0);
  }

  const rejectedUsers = [];
  snapshot.forEach((doc) => {
    const data = doc.data();
    rejectedUsers.push({
      userId: doc.id,
      email: data.email,
      username: data.username || data.name || 'N/A',
      rejectionReason: data.dating?.rejectionReason || 'N/A',
      rejectedAt: data.dating?.rejectedAt?.toDate?.() || data.dating?.rejectedAt || 'N/A',
      profileCompleted: data.dating?.profileCompleted,
      hasPhotos: data.photos && data.photos.length > 0,
      hasAudio: data.audioPrompts && data.audioPrompts.length > 0,
    });
  });

  console.log(`📋 Total Rejected Profiles: ${rejectedUsers.length}\n`);
  console.log('='.repeat(80));

  rejectedUsers.forEach((user, idx) => {
    console.log(`\n${idx + 1}. ${user.email}`);
    console.log(`   └─ User ID: ${user.userId}`);
    console.log(`   └─ Username: ${user.username}`);
    console.log(`   └─ Rejection Reason: ${user.rejectionReason}`);
    console.log(`   └─ Rejected At: ${user.rejectedAt}`);
    console.log(`   └─ profileCompleted: ${user.profileCompleted}`);
    console.log(`   └─ Has Photos: ${user.hasPhotos}`);
    console.log(`   └─ Has Audio: ${user.hasAudio}`);
  });

  console.log('\n' + '='.repeat(80));
  console.log(`\n✅ Preview complete. Ready to cleanup ${rejectedUsers.length} profile(s).\n`);
  process.exit(0);
})();
