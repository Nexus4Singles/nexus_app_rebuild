import admin from "firebase-admin";

function die(msg) {
  console.error(msg);
  process.exit(1);
}

const [, , uidA, uidB] = process.argv;
if (!uidA || !uidB) die("Usage: node tool/firestore_seed_nexus2_chat_adc.mjs UID_A UID_B");

// Uses Application Default Credentials from `gcloud auth application-default login`
admin.initializeApp();

const db = admin.firestore();

(async () => {
  const now = admin.firestore.Timestamp.now();

  // Find existing convo containing uidA, then check for uidB
  const existing = await db
    .collection("nexus2_chats")
    .where("participantIds", "array-contains", uidA)
    .limit(50)
    .get();

  for (const doc of existing.docs) {
    const data = doc.data() || {};
    const p = Array.isArray(data.participantIds) ? data.participantIds : [];
    if (p.includes(uidA) && p.includes(uidB)) {
      console.log(`Already exists: nexus2_chats/${doc.id}`);
      process.exit(0);
    }
  }

  const convoDoc = {
    participantIds: [uidA, uidB],
    lastMessage: "seed message",
    lastMessageAt: now,
    lastMessageSenderId: uidA,
    unreadCounts: { [uidA]: 0, [uidB]: 1 },
    lastReadAt: { [uidA]: now, [uidB]: null },
    createdAt: now,
    updatedAt: now,
    isActive: true,
  };

  const convoRef = await db.collection("nexus2_chats").add(convoDoc);

  await convoRef.collection("messages").add({
    senderId: uidA,
    text: "seed message",
    messageType: "text",
    createdAt: now,
  });

  console.log(`Created: nexus2_chats/${convoRef.id} (with 1 message)`);
})();
