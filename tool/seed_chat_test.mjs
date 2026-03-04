import admin from "firebase-admin";
import fs from "fs";

const sa = JSON.parse(fs.readFileSync("./serviceAccount.json", "utf8"));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const UID1 = "C8zK6n5I60Y3AQ6btHpTGPDhUsS2"; // bajomooluwapelumi@gmail.com (male)
const UID2 = "88yfMAJ8UXUAfYFsCr1EGbXOJno1"; // nexusgodlydatingapp@gmail.com (female)

(async () => {
  // ── Step 1: Check user gender data ──
  for (const uid of [UID1, UID2]) {
    const snap = await db.collection("users").doc(uid).get();
    const d = snap.data() || {};
    console.log("--- UID:", uid, "---");
    console.log("root gender:", d.gender || "(none)");
    const datingGender = d.dating?.profile?.gender || d.dating?.gender || "(none)";
    console.log("dating gender:", datingGender);
    const nexus2Gender = d.nexus2?.gender || "(none)";
    console.log("nexus2 gender:", nexus2Gender);
    console.log("displayName:", d.displayName || d.username || d.name || "(none)");
    console.log("chat:", JSON.stringify(d.chat || {}));
    console.log("");
  }

  // ── Step 2: Check if deterministic chat already exists ──
  const sorted = [UID1, UID2].sort();
  const chatId = sorted[0] + "_" + sorted[1];
  console.log("Deterministic chatId:", chatId);

  const chatDoc = await db.collection("nexus2_chats").doc(chatId).get();
  console.log("Chat already exists?", chatDoc.exists);
  if (chatDoc.exists) {
    console.log("Existing chat data:", JSON.stringify(chatDoc.data(), null, 2));
  }

  // Also check random-id chats between the two
  const q = await db.collection("nexus2_chats").where("participantIds", "array-contains", UID1).get();
  console.log("Total chats containing UID1:", q.docs.length);
  for (const doc of q.docs) {
    const p = doc.data().participantIds || [];
    if (p.includes(UID2)) {
      console.log("Found existing chat between both users:", doc.id);
    }
  }

  // ── Step 3: Create the conversation doc ──
  const now = admin.firestore.Timestamp.now();
  const chatRef = db.collection("nexus2_chats").doc(chatId);

  if (chatDoc.exists) {
    console.log("\nChat doc already exists, skipping creation.");
  } else {
    const convoData = {
      participantIds: sorted,
      lastMessage: "Hi",
      lastMessageAt: now,
      lastMessageSenderId: UID1,
      lastMessagePreview: "Hi",
      unreadCounts: { [UID1]: 0, [UID2]: 1 },
      createdAt: now,
      updatedAt: now,
      isActive: true,
    };

    await chatRef.set(convoData);
    console.log("\nCreated nexus2_chats/" + chatId);
  }

  // ── Step 4: Create a "Hi" message from UID1 (male) to UID2 (female) ──
  const msgRef = chatRef.collection("messages").doc();
  const msgData = {
    chatId: chatId,
    senderId: UID1,
    receiverId: UID2,
    content: "Hi",
    type: "text",
    sentAt: now,
    readAt: null,
    isRead: false,
    metadata: null,
  };
  await msgRef.set(msgData);
  console.log("Created message:", msgRef.id, "in nexus2_chats/" + chatId + "/messages");

  console.log("\nDone. bajomooluwapelumi@gmail.com (male) sent 'Hi' to nexusgodlydatingapp@gmail.com (female).");
  process.exit(0);
})();
