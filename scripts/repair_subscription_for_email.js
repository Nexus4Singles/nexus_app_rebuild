/*
  repair_subscription_for_email.js
  Usage: node scripts/repair_subscription_for_email.js contact@example.com

  This script will:
  - look up the user by email
  - read `lastLocalSubscriptionAttempt` and `revenueCat.customerId`
  - create a revenuecatMappings/{customerId} -> { firebaseUid }
  - update users/{uid}.subscription to active using optimistic data
  - add an auditLog entry

  WARNING: This performs server-side writes to user subscription data.
*/

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const SERVICE_ACCOUNT_PATH = path.resolve(__dirname, '..', 'serviceAccount.json');

if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error(`serviceAccount.json not found at ${SERVICE_ACCOUNT_PATH}`);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(SERVICE_ACCOUNT_PATH)),
});

const db = admin.firestore();

const email = process.argv[2];
if (!email) {
  console.error('Usage: node scripts/repair_subscription_for_email.js user@example.com');
  process.exit(1);
}

async function repair(email) {
  try {
    console.log(`Looking up user for email: ${email}`);
    const userRecord = await admin.auth().getUserByEmail(email);
    const uid = userRecord.uid;
    console.log(`Found uid=${uid} for ${email}. Reading user document...`);

    const userRef = db.collection('users').doc(uid);
    const snap = await userRef.get();
    if (!snap.exists) {
      console.error('User document does not exist in Firestore');
      return;
    }

    const data = snap.data() || {};
    const lastLocal = data.lastLocalSubscriptionAttempt || null;
    const rc = data.revenueCat || {};
    const rcCustomerId = rc.customerId || lastLocal?.revenueCatCustomerId || null;

    if (!lastLocal) {
      console.error('No lastLocalSubscriptionAttempt found; aborting to avoid guessing values.');
      return;
    }

    if (!rcCustomerId) {
      console.warn('No RevenueCat customerId found. Proceeding to write subscription fields using lastLocalSubscriptionAttempt values.');
    } else {
      // Create mapping doc
      const mappingRef = db.collection('revenuecatMappings').doc(rcCustomerId);
      await mappingRef.set({
        firebaseUid: uid,
        source: 'repair_script',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      console.log(`Created/updated revenuecatMappings/${rcCustomerId}`);
    }

    // Build subscription fields from lastLocal
    const expiry = lastLocal.expiryDate || null;
    const tier = lastLocal.tier || 'monthly_premium';
    const packageId = lastLocal.packageId || null;
    const transactionId = lastLocal.revenueCatTransactionId || lastLocal.transactionId || null;

    const updateData = {
      'subscription.isActive': true,
      'subscription.tier': tier,
      'subscription.startDate': lastLocal.startDate ? admin.firestore.Timestamp.fromDate(new Date(lastLocal.startDate._seconds * 1000)) : admin.firestore.FieldValue.serverTimestamp(),
      'subscription.expiryDate': expiry ? admin.firestore.Timestamp.fromDate(new Date(expiry._seconds * 1000)) : null,
      'subscription.autoRenew': lastLocal.autoRenew === true,
      'subscription.revenueCatCustomerId': rcCustomerId || null,
      'subscription.revenueCatTransactionId': transactionId,
      'subscription.verificationStatus': 'verified',
      'subscription.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
      'onPremium': true,
      'subExpDate': expiry ? admin.firestore.Timestamp.fromDate(new Date(expiry._seconds * 1000)) : null,
      'entitledUser': true,
      'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    };

    // Perform transactionally
    await db.runTransaction(async (tx) => {
      tx.update(userRef, updateData);
      const auditRef = userRef.collection('auditLog').doc();
      tx.set(auditRef, {
        action: 'manual_subscription_repair',
        source: 'repair_subscription_for_email.js',
        performedBy: 'automation-agent',
        performedAt: admin.firestore.FieldValue.serverTimestamp(),
        details: {
          rcCustomerId: rcCustomerId || null,
          fromLastLocal: !!lastLocal,
          packageId,
          transactionId,
        }
      });
    });

    console.log(`✅ Updated subscription fields for ${email} (uid=${uid})`);
  } catch (err) {
    console.error('Error repairing subscription:', err.message || err);
  }
}

repair(email).then(() => process.exit(0));
