#!/usr/bin/env node
const admin = require('firebase-admin');
const sa = require('./serviceAccount.json');
admin.initializeApp({ credential: admin.credential.cert(sa), projectId: 'nexus-visibility-app' });
const db = admin.firestore();

async function main() {
  const snap = await db.collection('users').where('email', '==', 'ayomidebaj@gmail.com').limit(1).get();
  if (snap.empty) return console.log('User not found');
  const d = snap.docs[0].data();
  const uid = snap.docs[0].id;

  console.log('=== USER DOC ===');
  console.log('UID:', uid);
  console.log('subscription:', JSON.stringify(d.subscription, null, 2));
  console.log('chat:', JSON.stringify(d.chat, null, 2));
  console.log('v1 isSubscribed:', d.isSubscribed);
  console.log('v1 subscriptionType:', d.subscriptionType);
  console.log('v1 isPremium:', d.isPremium);
  console.log('role:', d.role);
  console.log('isAdmin:', d.isAdmin);
  console.log('createdAt:', d.createdAt ? d.createdAt.toDate().toISOString() : 'N/A');

  console.log('\n=== CHATS ===');
  const chats = await db.collection('nexus2_chats').where('participantIds', 'array-contains', uid).get();
  console.log('Total chats:', chats.size);
  chats.docs.forEach(c => {
    const cd = c.data();
    console.log(' -', c.id);
    console.log('    lastMessage:', cd.lastMessage);
    console.log('    isActive:', cd.isActive);
    console.log('    participants:', cd.participantIds);
  });

  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });
