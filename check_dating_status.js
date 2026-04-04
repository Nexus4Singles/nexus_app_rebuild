const admin = require('firebase-admin');
const s = require('./serviceAccount.json');
admin.initializeApp({credential: admin.credential.cert(s)});
const db = admin.firestore();

(async () => {
  const uid = process.argv[2];
  const doc = await db.collection('users').doc(uid).get();
  if (!doc.exists) { console.log('User not found'); process.exit(1); }
  const d = doc.data();

  console.log('=== ACCOUNT INFO ===');
  console.log('Email:', d.email);
  console.log('displayName:', d.displayName);
  console.log('isActive:', d.isActive);
  console.log('dating_enabled:', d.dating_enabled);

  console.log('\n=== DATING FIELDS ===');
  const dating = d.dating || {};
  console.log('dating.optIn:', dating.optIn);
  console.log('dating.isActive:', dating.isActive);
  console.log('dating.enabled:', dating.enabled);
  console.log('dating.isDiscoverable:', dating.isDiscoverable);
  console.log('dating.profileCompleted:', dating.profileCompleted);
  console.log('dating.verificationStatus:', dating.verificationStatus);
  console.log('dating.archivedAt:', dating.archivedAt ? dating.archivedAt.toDate().toISOString() : 'NOT SET');
  console.log('dating.createdAt:', dating.createdAt ? dating.createdAt.toDate().toISOString() : 'NOT SET');
  console.log('dating.schemaVersion:', dating.schemaVersion);

  console.log('\n=== SUBSCRIPTION ===');
  console.log('onPremium:', d.onPremium);
  console.log('subscription.isActive:', d.subscription && d.subscription.isActive);
  console.log('subscription.tier:', d.subscription && d.subscription.tier);
  const expiry = d.subscription && d.subscription.expiryDate;
  console.log('subscription.expiryDate:', expiry ? expiry.toDate().toISOString() : 'NOT SET');

  console.log('\n=== RELATIONSHIP STATUS ===');
  console.log('nexus.relationshipStatus:', d.nexus && d.nexus.relationshipStatus);
  console.log('nexus2.relationshipStatus:', d.nexus2 && d.nexus2.relationshipStatus);
})();
