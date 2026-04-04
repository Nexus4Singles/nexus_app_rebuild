#!/usr/bin/env node
const admin = require('firebase-admin');
const sa = require('./serviceAccount.json');
admin.initializeApp({ credential: admin.credential.cert(sa), projectId: 'nexus-visibility-app' });
const db = admin.firestore();

const chatIds = [
  '5gSsntMpsSOnJS1t4j0V61uvUFL2_yjXNtVfxyraQBmD2LEvvaiGWrJo1',
  '5gSsntMpsSOnJS1t4j0V61uvUFL2_oWt4d9MdquYWYWRVgkQFxNTZ8NJ2',
];

async function main() {
  for (const chatId of chatIds) {
    await db.collection('nexus2_chats').doc(chatId).update({
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('Touched:', chatId);
  }
  console.log('Done. Both chats refreshed — stream listeners should fire now.');
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
