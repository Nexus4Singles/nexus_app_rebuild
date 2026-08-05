/*
Set the user's chat.freeChatPartnerIds to a provided list (admin script).
Usage:
  node scripts/set_user_free_partners.js <userId> <senderId1> [senderId2] [...]

Example:
  node scripts/set_user_free_partners.js G11kHare1WWvFtKWT8SWeaCoQzt2 injected_sender_e19ab48a injected_sender_e0bb8aa3
*/

const admin = require('firebase-admin');
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

async function main() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error('Usage: node set_user_free_partners.js <userId> <senderId1> [senderId2] [...]');
    process.exit(1);
  }
  const userId = args[0];
  const partners = args.slice(1);

  console.log(`Setting user ${userId} freeChatPartnerIds = [${partners.join(', ')}]`);
  const userRef = firestore.collection('users').doc(userId);
  await userRef.set({ chat: { freeChatPartnerIds: partners } }, { merge: true });
  console.log('Done.');
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
