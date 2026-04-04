#!/usr/bin/env node
/**
 * Creates a chat initiated by ayomidebaj@gmail.com → contact@nexus4singles.com
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

async function main() {
  const senderEmail   = 'ayomidebaj@gmail.com';
  const receiverEmail = 'contact@nexus4singles.com';

  console.log(`Looking up users...`);
  const senderUid   = await getUid(senderEmail);
  const receiverUid = await getUid(receiverEmail);

  console.log(`  ${senderEmail}   → ${senderUid}`);
  console.log(`  ${receiverEmail} → ${receiverUid}`);

  const ids    = [senderUid, receiverUid].sort();
  const chatId = ids.join('_');
  const chatRef = db.collection('nexus2_chats').doc(chatId);
  const now = admin.firestore.Timestamp.now();

  // Check if chat already exists
  const existing = await chatRef.get();
  if (existing.exists) {
    console.log(`\nChat already exists (${chatId}). Skipping creation.`);
  } else {
    const firstMessage = 'Hi there!';

    // Create chat document
    await chatRef.set({
      participantIds: ids,
      createdAt: now,
      updatedAt: now,
      lastMessageAt: now,
      lastMessage: firstMessage,
      lastMessageSenderId: senderUid,
      unreadCounts: { [senderUid]: 0, [receiverUid]: 1 },
      isActive: true,
    });
    console.log(`\n✅ Chat doc created: ${chatId}`);

    // Add the opening message to the messages subcollection
    const msgRef = chatRef.collection('messages').doc();
    await msgRef.set({
      id: msgRef.id,
      chatId,
      senderId: senderUid,
      receiverId: receiverUid,
      content: firstMessage,
      type: 'text',
      sentAt: now,
      isRead: false,
      metadata: {},
    });
    console.log(`✅ Message added: "${firstMessage}" (${msgRef.id})`);
  }

  // Verify
  console.log('\nVerifying chat...');
  const chatDoc = await chatRef.get();
  const data = chatDoc.data();
  console.log('  lastMessage:', data.lastMessage);
  console.log('  lastMessageSenderId:', data.lastMessageSenderId);
  console.log('  unreadCounts:', JSON.stringify(data.unreadCounts));
  console.log('  isActive:', data.isActive);

  console.log(`\n✅ Done! Open the app as ${receiverEmail} — the chat from Ayomide should appear.`);
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
