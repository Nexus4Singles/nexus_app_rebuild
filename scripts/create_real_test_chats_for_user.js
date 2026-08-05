/*
Create real test chats for a receiver user with sender user accounts.
Usage:
  node scripts/create_real_test_chats_for_user.js <receiverEmail> [chatCount] [messagesPerChat]

Example:
  node scripts/create_real_test_chats_for_user.js bajomooluwapelumi@gmail.com 4 4

This creates sender user docs under /users and chat/message docs under /nexus2_chats.
It also updates the receiver's free chat partner list to allow the first two senders.
*/

const admin = require('firebase-admin');
const crypto = require('crypto');
const path = require('path');

const svcPath = path.resolve(__dirname, '..', 'serviceAccount.json');
let serviceAccount;
try {
  serviceAccount = require(svcPath);
} catch (err) {
  console.error('Could not load serviceAccount.json from', svcPath, err);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const firestore = admin.firestore();

function randomId(prefix = 'test_sender') {
  return `${prefix}_${crypto.randomBytes(4).toString('hex')}`;
}

function chatIdFor(a, b) {
  return [a.trim(), b.trim()].sort().join('_');
}

async function ensureUser(uid, displayName) {
  const ref = firestore.collection('users').doc(uid);
  const doc = await ref.get();
  if (!doc.exists) {
    await ref.set({
      uid,
      username: displayName.toLowerCase().replace(/[^a-z0-9]/g, '_'),
      displayName,
      name: displayName,
      isActive: true,
      chatEnabled: true,
      gender: 'male',
      schemaVersion: 2,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

async function createChatWithMessages(senderId, receiverId, displayName, messagesPerChat) {
  await ensureUser(senderId, displayName);
  const chatId = chatIdFor(senderId, receiverId);
  const chatRef = firestore.collection('nexus2_chats').doc(chatId);

  await chatRef.set({
    participantIds: [senderId, receiverId].sort(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastMessage: '',
    lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
    lastMessageSenderId: senderId,
    unreadCounts: { [receiverId]: 0, [senderId]: 0 },
    isActive: true,
  }, { merge: true });

  for (let i = 0; i < messagesPerChat; i++) {
    const msgRef = chatRef.collection('messages').doc();
    const content = `Hello ${displayName} test message ${i + 1}`;
    const sentAt = new Date(Date.now() + i * 1000);
    await msgRef.set({
      id: msgRef.id,
      chatId,
      senderId,
      receiverId,
      content,
      type: 'text',
      sentAt: admin.firestore.Timestamp.fromDate(sentAt),
      metadata: {},
      isDeclined: false,
    });
    await chatRef.update({
      lastMessage: content,
      lastMessageAt: admin.firestore.Timestamp.fromDate(sentAt),
      lastMessageSenderId: senderId,
      [`unreadCounts.${receiverId}`]: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return chatId;
}

async function main() {
  const args = process.argv.slice(2);
  if (args.length < 1) {
    console.error('Usage: node create_real_test_chats_for_user.js <receiverEmail> [chatCount] [messagesPerChat]');
    process.exit(1);
  }

  const receiverEmail = args[0];
  const chatCount = parseInt(args[1] || '4', 10);
  const messagesPerChat = parseInt(args[2] || '4', 10);

  const userQuery = await firestore.collection('users').where('email', '==', receiverEmail).limit(1).get();
  if (userQuery.empty) {
    console.error('Receiver email not found:', receiverEmail);
    process.exit(1);
  }

  const receiverId = userQuery.docs[0].id;
  console.log('Receiver userId:', receiverId);

  const senderIds = [];
  for (let i = 0; i < chatCount; i++) {
    senderIds.push(`real_test_sender_${i + 1}_${crypto.randomBytes(3).toString('hex')}`);
  }

  const createdChats = [];
  for (let i = 0; i < senderIds.length; i++) {
    const senderId = senderIds[i];
    const displayName = `Test Sender ${i + 1}`;
    const chatId = await createChatWithMessages(senderId, receiverId, displayName, messagesPerChat);
    createdChats.push(chatId);
    console.log(`Created chat ${chatId}`);
  }

  const allowed = senderIds.slice(0, 2);
  await firestore.collection('users').doc(receiverId).set({
    chat: {
      freeChatPartnerIds: allowed,
      freeChatPartnerId: allowed[0],
    },
    freeChatPartnerIds: allowed,
    freeChatPartnerId: allowed[0],
  }, { merge: true });

  console.log('Allowed free chat partners set to:', allowed);
  console.log('Created chats:', createdChats);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
