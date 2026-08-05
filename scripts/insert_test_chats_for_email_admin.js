/*
Injector using firebase-admin to find a user by email and create test chats/messages.
Usage:
  node scripts/insert_test_chats_for_email_admin.js <email> [chatCount] [messagesPerChat]

Example:
  node scripts/insert_test_chats_for_email_admin.js bajomooluwapelumi@gmail.com 4 4

This script requires that `serviceAccount.json` exists at repo root and has Firestore write access.
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

function randomId(prefix = 'injected') {
  return `${prefix}_${crypto.randomBytes(4).toString('hex')}`;
}

function chatIdFor(a, b) {
  const x = a.trim();
  const y = b.trim();
  const ids = [x, y].sort();
  return `${ids[0]}_${ids[1]}`;
}

async function insertChatAndMessages(senderId, receiverId, messagesPerChat) {
  const chatId = chatIdFor(senderId, receiverId);
  const chatRef = firestore.collection('nexus2_chats').doc(chatId);
  const messagesRef = chatRef.collection('messages');

  // Ensure chat doc exists
  const now = new Date();
  await chatRef.set({
    participantIds: [senderId, receiverId].sort(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastMessage: '',
    lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
    lastMessageSenderId: '',
    unreadCounts: { [receiverId]: 0 },
    isActive: true,
  }, { merge: true });

  for (let i = 0; i < messagesPerChat; i++) {
    const docRef = messagesRef.doc();
    const body = `Injected test message ${i + 1} from ${senderId}`;
    const sentAt = new Date(Date.now() + i * 1000);

    await docRef.set({
      id: docRef.id,
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      content: body,
      type: 'text',
      sentAt: admin.firestore.Timestamp.fromDate(sentAt),
      metadata: {},
    });

    await chatRef.update({
      lastMessage: body,
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
    console.error('Usage: node insert_test_chats_for_email_admin.js <email> [chatCount] [messagesPerChat]');
    process.exit(1);
  }

  const email = args[0];
  const chatCount = parseInt(args[1] || '4', 10);
  const messagesPerChat = parseInt(args[2] || '4', 10);

  console.log(`Resolving user with email=${email}`);

  const usersQuery = await firestore.collection('users').where('email', '==', email).limit(1).get();
  if (usersQuery.empty) {
    console.error('No user found with that email. Aborting.');
    process.exit(1);
  }
  const userDoc = usersQuery.docs[0];
  const receiverId = userDoc.id;

  console.log(`Found user doc id=${receiverId}. Creating ${chatCount} chats with ${messagesPerChat} messages each.`);

  for (let c = 0; c < chatCount; c++) {
    const senderId = randomId('injected_sender');
    try {
      const chatId = await insertChatAndMessages(senderId, receiverId, messagesPerChat);
      console.log(`Created chat ${chatId}`);
    } catch (err) {
      console.error('Failed to create chat/messages for', senderId, err);
    }
  }

  console.log('Done.');
  process.exit(0);
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
