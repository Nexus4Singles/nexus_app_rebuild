/*
Insert multiple test chats and messages for a target user.

Usage:
  node scripts/insert_test_chats_for_user.js <receiverId> [chatCount] [messagesPerChat]

Example:
  node scripts/insert_test_chats_for_user.js userB 4 4

Defaults: chatCount=4, messagesPerChat=4

Notes:
- Requires `GOOGLE_APPLICATION_CREDENTIALS` pointing to a service account JSON
  with write access to Firestore for the project's DB.
- The script will create chats under `nexus2_chats/<chatId>` and a `messages`
  subcollection with text messages. It will also update `lastMessage*` fields
  and increment the receiver's unread count.
- Chat IDs follow the app convention: `'<smallerUid>_<largerUid>'`.
- Use carefully in production; this will write to your Firestore.
*/

const { Firestore } = require('@google-cloud/firestore');
const crypto = require('crypto');

function randomId(prefix = 'injected') {
  return `${prefix}_${crypto.randomBytes(4).toString('hex')}`;
}

function chatIdFor(a, b) {
  const x = a.trim();
  const y = b.trim();
  const ids = [x, y].sort();
  return `${ids[0]}_${ids[1]}`;
}

async function insertChatAndMessages(firestore, senderId, receiverId, messagesPerChat) {
  const chatId = chatIdFor(senderId, receiverId);
  const chatRef = firestore.collection('nexus2_chats').doc(chatId);
  const messagesRef = chatRef.collection('messages');

  // Ensure chat doc exists (merge to not overwrite)
  const now = new Date();
  await chatRef.set({
    participantIds: [senderId, receiverId].sort(),
    createdAt: Firestore.Timestamp ? Firestore.Timestamp.fromDate(now) : now,
    updatedAt: Firestore.FieldValue.serverTimestamp(),
    lastMessage: '',
    lastMessageAt: Firestore.FieldValue.serverTimestamp(),
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
      sentAt: Firestore.Timestamp ? Firestore.Timestamp.fromDate(sentAt) : sentAt,
      metadata: {},
    });

    // Best-effort update to chat doc
    await chatRef.update({
      lastMessage: body,
      lastMessageAt: Firestore.Timestamp ? Firestore.Timestamp.fromDate(sentAt) : sentAt,
      lastMessageSenderId: senderId,
      [`unreadCounts.${receiverId}`]: Firestore.FieldValue.increment(1),
      updatedAt: Firestore.FieldValue.serverTimestamp(),
    });
  }

  return chatId;
}

async function main() {
  const args = process.argv.slice(2);
  if (args.length < 1) {
    console.error('Usage: node insert_test_chats_for_user.js <receiverId> [chatCount] [messagesPerChat]');
    process.exit(1);
  }

  const receiverId = args[0];
  const chatCount = parseInt(args[1] || '4', 10);
  const messagesPerChat = parseInt(args[2] || '4', 10);

  if (!receiverId || receiverId.trim() === '') {
    console.error('Invalid receiverId');
    process.exit(1);
  }

  const firestore = new Firestore();

  console.log(`Will create ${chatCount} chats with ${messagesPerChat} messages each for receiver '${receiverId}'`);

  for (let c = 0; c < chatCount; c++) {
    const senderId = randomId('injected_sender');
    console.log(`Creating chat ${c + 1}/${chatCount}: sender=${senderId}`);
    try {
      const chatId = await insertChatAndMessages(firestore, senderId, receiverId, messagesPerChat);
      console.log(`Created chat ${chatId}`);
    } catch (err) {
      console.error('Failed to create chat/messages for', senderId, err);
    }
  }

  console.log('Done.');
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
