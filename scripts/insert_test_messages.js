/*
Simple Firestore test injector for Nexus messages.
Usage:
  node scripts/insert_test_messages.js <chatId> <senderId> <receiverId> [count]

Example:
  node scripts/insert_test_messages.js userA_userB userA userB 4

Notes:
- Requires GOOGLE_APPLICATION_CREDENTIALS env var pointing to a service account JSON with
  write access to Firestore for this project (same project the app uses).
- This script inserts `count` text messages with distinct bodies and timestamps.
- It updates the parent chat doc's `lastMessage`, `lastMessageAt`, `lastMessageSenderId`,
  and increments the receiver unread count.
- Use cautiously in production.
*/

const { Firestore } = require('@google-cloud/firestore');

async function main() {
  const args = process.argv.slice(2);
  if (args.length < 3) {
    console.error('Usage: node insert_test_messages.js <chatId> <senderId> <receiverId> [count]');
    process.exit(1);
  }
  const [chatId, senderId, receiverId] = args;
  const count = parseInt(args[3] || '4', 10);

  const firestore = new Firestore();
  const chatRef = firestore.collection('nexus2_chats').doc(chatId);
  const messagesRef = chatRef.collection('messages');

  console.log(`Inserting ${count} messages into chat ${chatId} from ${senderId} -> ${receiverId}`);

  for (let i = 0; i < count; i++) {
    const docRef = messagesRef.doc();
    const body = `Test message ${i + 1} (injected)`;
    const now = new Date();
    await docRef.set({
      id: docRef.id,
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      content: body,
      type: 'text',
      sentAt: Firestore.Timestamp ? Firestore.Timestamp.fromDate(now) : now,
      metadata: {},
    });

    // Update chat metadata
    await chatRef.update({
      lastMessage: body,
      lastMessageAt: Firestore.Timestamp ? Firestore.Timestamp.fromDate(now) : now,
      lastMessageSenderId: senderId,
      [`unreadCounts.${receiverId}`]: Firestore.FieldValue.increment(1),
      updatedAt: Firestore.FieldValue.serverTimestamp(),
    }).catch(async (err) => {
      // If chat doc doesn't exist, create it
      if (err && err.code && (err.code === 5 || err.code === 'not-found')) {
        await chatRef.set({
          participantIds: chatId.split('_'),
          createdAt: Firestore.FieldValue.serverTimestamp(),
          updatedAt: Firestore.FieldValue.serverTimestamp(),
          lastMessage: body,
          lastMessageAt: Firestore.FieldValue.serverTimestamp(),
          lastMessageSenderId: senderId,
          unreadCounts: { [receiverId]: 1 },
          isActive: true,
        });
      } else {
        console.error('Failed to update chat doc:', err);
      }
    });

    console.log(`Inserted message ${i + 1}/${count}`);
  }

  console.log('Done.');
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
