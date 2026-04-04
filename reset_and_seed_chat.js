#!/usr/bin/env node
/**
 * Clean up test chats and create a proper chat from nexus4singles -> contact.
 * Uses the correct Firestore field names that the app actually reads:
 *   - lastMessage (NOT lastMessagePreview)
 *   - lastMessageSenderId
 *   - unreadCounts
 */
const admin = require('firebase-admin');
const sa = require('./serviceAccount.json');
admin.initializeApp({ credential: admin.credential.cert(sa), projectId: 'nexus-visibility-app' });
const db = admin.firestore();

async function getUid(email) {
  const snap = await db.collection('users').where('email', '==', email).limit(1).get();
  if (snap.empty) throw new Error('User not found: ' + email);
  return snap.docs[0].id;
}

async function deleteCollection(ref) {
  const snap = await ref.get();
  if (snap.empty) return;
  const batch = db.batch();
  snap.docs.forEach(d => batch.delete(d.ref));
  await batch.commit();
  console.log(`  Deleted ${snap.size} docs from ${ref.path}`);
}

async function main() {
  const uidA = await getUid('nexus4singles@gmail.com');   // sender (premium)
  const uidB = await getUid('contact@nexus4singles.com'); // receiver
  const uidC = await getUid('nexusgodlydatingapp@gmail.com');

  console.log('UIDs:');
  console.log('  nexus4singles (A):', uidA);
  console.log('  contact       (B):', uidB);
  console.log('  nexusgodly    (C):', uidC);

  // ── Step 1: Delete all seeded test chats for contact ──────────────────────
  console.log('\n[1] Deleting old seeded test chats...');
  const staleIds = [
    `${[uidA, uidB].sort().join('_')}`, // contact <-> nexus4singles
    `${[uidB, uidC].sort().join('_')}`, // contact <-> nexusgodly
  ];
  for (const chatId of staleIds) {
    const chatRef = db.collection('nexus2_chats').doc(chatId);
    const chatDoc = await chatRef.get();
    if (chatDoc.exists) {
      await deleteCollection(chatRef.collection('messages'));
      await chatRef.delete();
      console.log('  Deleted chat:', chatId);
    } else {
      console.log('  (not found, skipping):', chatId);
    }
  }

  // ── Step 2: Reset contact's freeChatPartnerIds ────────────────────────────
  console.log('\n[2] Resetting contact freeChatPartnerIds to []...');
  await db.collection('users').doc(uidB).set({
    chat: { freeChatPartnerIds: [] },
  }, { merge: true });
  console.log('  Done.');

  // ── Step 3: Create a fresh proper chat ────────────────────────────────────
  console.log('\n[3] Creating fresh chat: nexus4singles -> contact...');
  const ids = [uidA, uidB].sort();
  const chatId = ids.join('_');
  const chatRef = db.collection('nexus2_chats').doc(chatId);
  const now = admin.firestore.Timestamp.now();

  await chatRef.set({
    participantIds: ids,
    createdAt: now,
    updatedAt: now,
    lastMessageAt: now,
    lastMessage: 'Hi',            // ← correct field the app reads
    lastMessageSenderId: uidA,
    unreadCounts: { [uidA]: 0, [uidB]: 1 },  // contact has 1 unread
    isActive: true,
  });
  console.log('  Chat doc created:', chatId);

  // Add the message to the messages subcollection
  const msgRef = chatRef.collection('messages').doc();
  await msgRef.set({
    id: msgRef.id,
    chatId: chatId,
    senderId: uidA,
    receiverId: uidB,
    content: 'Hi',
    type: 'text',
    sentAt: now,
    isRead: false,
    metadata: {},
  });
  console.log('  Message added:', msgRef.id);

  // ── Step 4: Confirm ────────────────────────────────────────────────────────
  console.log('\n[4] Verifying...');
  const checkB = await db.collection('users').doc(uidB).get();
  const bData = checkB.data();
  console.log('  contact freeChatPartnerIds:', JSON.stringify(bData.chat?.freeChatPartnerIds));

  const checkChat = await chatRef.get();
  const cd = checkChat.data();
  console.log('  Chat lastMessage:', cd.lastMessage);
  console.log('  Chat unreadCounts:', JSON.stringify(cd.unreadCounts));
  console.log('  Chat isActive:', cd.isActive);

  console.log('\n✅ Done! Open the app as contact@nexus4singles.com — the chat from Ayodele should now appear.');
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
