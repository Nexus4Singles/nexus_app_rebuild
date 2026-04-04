#!/usr/bin/env node
// Seed two test chats for chat-limit testing:
//   Chat 1: nexus4singles@gmail.com  →  contact@nexus4singles.com   (sender = nexus4singles)
//   Chat 2: contact@nexus4singles.com → nexusgodlydatingapp@gmail.com (sender = contact)

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app',
});

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// ─── helpers ─────────────────────────────────────────────────────────────────

async function getUidByEmail(email) {
  const snap = await db.collection('users').where('email', '==', email).limit(1).get();
  if (snap.empty) throw new Error(`User not found for email: ${email}`);
  return snap.docs[0].id;
}

function chatIdFor(uid1, uid2) {
  return [uid1, uid2].sort().join('_');
}

async function ensureChat(uid1, uid2) {
  const ids = [uid1, uid2].sort();
  const chatId = ids.join('_');
  const chatRef = db.collection('nexus2_chats').doc(chatId);

  const existing = await chatRef.get();
  if (!existing.exists) {
    await chatRef.set({
      participantIds: ids,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      lastMessageAt: FieldValue.serverTimestamp(),
      lastMessagePreview: '',
      unreadCounts: { [ids[0]]: 0, [ids[1]]: 0 },
      isActive: true,
    });
    console.log(`  ✅ Chat doc created: ${chatId}`);
  } else {
    console.log(`  ℹ️  Chat doc already exists: ${chatId}`);
  }
  return chatId;
}

async function sendMessage(chatId, senderId, receiverId, content) {
  const msgRef = db.collection('nexus2_chats').doc(chatId).collection('messages').doc();
  const now = FieldValue.serverTimestamp();

  const batch = db.batch();

  // Message document
  batch.set(msgRef, {
    id: msgRef.id,
    chatId,
    senderId,
    receiverId,
    content,
    type: 'text',
    sentAt: now,
    isRead: false,
    isDeleted: false,
  });

  // Update conversation metadata
  batch.update(db.collection('nexus2_chats').doc(chatId), {
    updatedAt: now,
    lastMessageAt: now,
    lastMessagePreview: content,
    [`unreadCounts.${receiverId}`]: FieldValue.increment(1),
  });

  await batch.commit();
  console.log(`  ✅ Message sent ("${content}") from ${senderId} → ${receiverId}`);

  // Record free-tier partner on sender's user doc (mirrors chat_service.dart logic)
  // Uses dot-notation merge to preserve all other user fields
  const senderRef = db.collection('users').doc(senderId);
  const senderSnap = await senderRef.get();
  const senderData = senderSnap.data() || {};

  // Check if already premium — if so, skip tracking
  const sub = senderData.subscription;
  let isPremium = false;
  if (sub && sub.isActive) {
    if (!sub.expiryDate || sub.expiryDate.toDate() > new Date()) {
      isPremium = true;
    }
  } else if (senderData.onPremium) {
    const exp = senderData.subExpDate;
    if (exp && exp.toDate() > new Date()) isPremium = true;
  }

  if (!isPremium) {
    const chatMap = senderData.chat || {};
    let partnerIds = Array.isArray(chatMap.freeChatPartnerIds) ? [...chatMap.freeChatPartnerIds] : [];

    // Legacy fallback
    if (partnerIds.length === 0 && chatMap.freeChatPartnerId) {
      partnerIds = [chatMap.freeChatPartnerId];
    }

    if (!partnerIds.includes(receiverId)) {
      partnerIds.push(receiverId);
      await senderRef.set(
        { chat: { freeChatPartnerIds: partnerIds } },
        { merge: true }
      );
      console.log(`  📝 Recorded free-tier partner for sender (${senderId}): [${partnerIds.join(', ')}]`);
    } else {
      console.log(`  ℹ️  Receiver already in sender's freeChatPartnerIds — no change`);
    }
  } else {
    console.log(`  ℹ️  Sender is premium — skipping freeChatPartnerIds update`);
  }
}

// ─── main ────────────────────────────────────────────────────────────────────

async function main() {
  console.log('\n🔍 Looking up user IDs...\n');

  const emailA = 'nexus4singles@gmail.com';
  const emailB = 'contact@nexus4singles.com';
  const emailC = 'nexusgodlydatingapp@gmail.com';

  const [uidA, uidB, uidC] = await Promise.all([
    getUidByEmail(emailA),
    getUidByEmail(emailB),
    getUidByEmail(emailC),
  ]);

  console.log(`  ${emailA} → ${uidA}`);
  console.log(`  ${emailB} → ${uidB}`);
  console.log(`  ${emailC} → ${uidC}`);

  // ── Chat 1: nexus4singles → contact ──────────────────────────────────────
  console.log('\n💬 Chat 1: nexus4singles → contact@nexus4singles.com');
  const chatId1 = await ensureChat(uidA, uidB);
  await sendMessage(chatId1, uidA, uidB, 'Hi');

  // ── Chat 2: contact → nexusgodly ─────────────────────────────────────────
  console.log('\n💬 Chat 2: contact@nexus4singles.com → nexusgodlydatingapp@gmail.com');
  const chatId2 = await ensureChat(uidB, uidC);
  await sendMessage(chatId2, uidB, uidC, 'Hi');

  console.log('\n✅ All done! Both chats seeded.\n');
  process.exit(0);
}

main().catch((err) => {
  console.error('\n❌ Error:', err.message);
  process.exit(1);
});
