/*
  inspect_user_payment_fields.js
  Usage: node scripts/inspect_user_payment_fields.js
  Reads a user's Firestore doc and prints payment/subscription-related fields.
*/

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const SERVICE_ACCOUNT_PATH = path.resolve(__dirname, '..', 'serviceAccount.json');
// Default target email; can be overridden via command-line: node scripts/inspect_user_payment_fields.js contact@example.com
const DEFAULT_EMAIL = 'ayomidebaj@gmail.com';
const TARGET_EMAIL = process.argv[2] || DEFAULT_EMAIL;

if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error(`serviceAccount.json not found at ${SERVICE_ACCOUNT_PATH}`);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(SERVICE_ACCOUNT_PATH)),
});

const db = admin.firestore();

async function inspect(email) {
  try {
    console.log(`Looking up user for email: ${email}`);
    const userRecord = await admin.auth().getUserByEmail(email);
    const uid = userRecord.uid;
    console.log(`Found uid=${uid} for ${email}. Fetching user document...`);

    const userRef = db.collection('users').doc(uid);
    const snap = await userRef.get();
    if (!snap.exists) {
      console.error('User document does not exist in Firestore');
      return;
    }

    const data = snap.data() || {};

    const keysOfInterest = [
      'subscription',
      'onPremium',
      'subExpDate',
      'entitledUser',
      'lastLocalSubscriptionAttempt',
      'lastFlutterwaveTransactionId',
      'lastPaymentMethod',
      'lastPaymentDate',
      'hasExternalSubscriptionFlow',
      'updatedAt',
      'purchasedJourneys',
      'revenueCat',
      'revenueCatCustomerId',
    ];

    const out = {};
    for (const key of keysOfInterest) {
      out[key] = key in data ? data[key] : null;
    }

    console.log('--- Subscription / Payment Fields ---');
    console.log(JSON.stringify(out, null, 2));

    // Check purchases subcollection document count and recent docs
    const purchasesSnap = await userRef.collection('purchases').orderBy('purchaseDate', 'desc').limit(10).get();
    console.log(`purchases.count: ${purchasesSnap.size}`);
    const purchases = [];
    purchasesSnap.forEach(doc => purchases.push({ id: doc.id, data: doc.data() }));
    console.log('recent purchases (up to 10):', JSON.stringify(purchases, null, 2));

    // Check notifications recent
    const notSnap = await userRef.collection('notifications').orderBy('createdAt', 'desc').limit(10).get();
    console.log(`notifications.count: ${notSnap.size}`);
    const notifs = [];
    notSnap.forEach(doc => notifs.push({ id: doc.id, data: doc.data() }));
    console.log('recent notifications (up to 10):', JSON.stringify(notifs, null, 2));

    // Check revenuecatMappings doc
    if (data.revenueCat && data.revenueCat.customerId) {
      const mapping = await db.collection('revenuecatMappings').doc(data.revenueCat.customerId).get();
      console.log('revenuecatMappings.exists:', mapping.exists);
      if (mapping.exists) console.log('revenuecatMappings.data:', JSON.stringify(mapping.data(), null, 2));
    }

    // Also fetch auditLog entries
    const auditSnap = await userRef.collection('auditLog').orderBy('recordedAt', 'desc').limit(10).get();
    console.log(`auditLog.count: ${auditSnap.size}`);
    const audits = [];
    auditSnap.forEach(doc => audits.push({ id: doc.id, data: doc.data() }));
    console.log('recent auditLog (up to 10):', JSON.stringify(audits, null, 2));

  } catch (err) {
    console.error('Error inspecting user:', err.message || err);
  }
}

inspect(TARGET_EMAIL).then(() => process.exit(0));
