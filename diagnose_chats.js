#!/usr/bin/env node
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount), projectId: 'nexus-visibility-app' });
const db = admin.firestore();

const emails = {
  A: 'nexus4singles@gmail.com',
  B: 'contact@nexus4singles.com',
  C: 'nexusgodlydatingapp@gmail.com',
};

async function getUid(email) {
  const snap = await db.collection('users').where('email', '==', email).limit(1).get();
  if (snap.empty) throw new Error('Not found: ' + email);
  return snap.docs[0].id;
}

async function main() {
  const uidA = await getUid(emails.A);
  const uidB = await getUid(emails.B);
  const uidC = await getUid(emails.C);
  console.log('UIDs:');
  console.log('  A (nexus4singles):', uidA);
  console.log('  B (contact):      ', uidB);
  console.log('  C (nexusgodly):   ', uidC);

  // Check each user's chat state
  for (const [label, uid] of [['A', uidA], ['B', uidB], ['C', uidC]]) {
    const doc = await db.collection('users').doc(uid).get();
    const d = doc.data() || {};
    const chatMap = d.chat || {};
    const sub = d.subscription || {};
    console.log('\n--- User', label, '(' + Object.values(emails)[['A','B','C'].indexOf(label)] + ') ---');
    console.log('  subscription.isActive:', sub.isActive || false);
    console.log('  freeChatPartnerIds:   ', JSON.stringify(chatMap.freeChatPartnerIds || []));
    console.log('  freeChatPartnerId:    ', chatMap.freeChatPartnerId || '(none)');
  }

  // Check chats in Firestore
  console.log('\n--- All nexus2_chats involving these users ---');
  const uids = [uidA, uidB, uidC];
  const seen = new Set();
  for (const uid of uids) {
    const snap = await db.collection('nexus2_chats').where('participantIds', 'array-contains', uid).get();
    snap.forEach(doc => {
      if (!seen.has(doc.id)) {
        seen.add(doc.id);
        const d = doc.data();
        console.log('  chatId:', doc.id);
        console.log('    participants:', d.participantIds);
        console.log('    lastPreview: "' + d.lastMessagePreview + '"');
        console.log('    isActive:   ', d.isActive);
        console.log('    createdAt:  ', d.createdAt ? d.createdAt.toDate().toISOString() : 'null');
      }
    });
  }

  // Check messages in each chat
  console.log('\n--- Messages ---');
  for (const chatId of seen) {
    const msgs = await db.collection('nexus2_chats').doc(chatId).collection('messages').orderBy('sentAt', 'asc').get();
    console.log('  Chat', chatId, '- message count:', msgs.size);
    msgs.forEach(m => {
      const d = m.data();
      console.log('    [', d.senderId, '->', d.receiverId, ']:', '"' + d.content + '"');
    });
  }

  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
