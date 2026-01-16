import admin from "firebase-admin";
import fs from "fs";

function die(msg) {
  console.error(msg);
  process.exit(1);
}

const [, , uidA, uidB, serviceAccountPath] = process.argv;

if (!uidA || !uidB) {
  die("Usage: node tool/firestore_seed_nexus2_chat.mjs <uidA> <uidB> <serviceAccount.json>");
}
if (!serviceAccountPath) die("Missing service account path argument.");
if (!fs.existsSync(serviceAccountPath)) die(`Service account file not found: ${serviceAccountPath}`);

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(fs.readFileSync(serviceAccountPath, "utf8"))),
});

const db = admin.firestore();

function sortedPairKey(a, b) {
  return [a, b].sort().join("_");
}

(async () => {
  const pairKey = sortedPairKey(uidA, uidB);

  // Try to find an existing conversation between these users:
  // Your app currently likely uses getConversationBetween() which probably queries participantIds.
  // We'll use a simple query that works with your schema.
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

  const now = admin.firestore.Timestamp.now();

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
    // Optional debug marker (harmless to v2, v1 ignores):
    nexus2_seedPairKey: pairKey,
  };

  const convoRef = await db.collection("nexus2_chats").add(convoDoc);

  // Create 1 message in the required subcollection name: "messages"
  await convoRef.collection("messages").add({
    senderId: uidA,
    text: "seed message",
    messageType: "text",
    createdAt: now,
  });

  console.log(`Created: nexus2_chats/${convoRef.id} (with 1 message)`);
})();
