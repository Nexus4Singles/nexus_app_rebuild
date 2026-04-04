#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function checkUser(email) {
  try {
    const snapshot = await db
      .collection('users')
      .where('email', '==', email)
      .get();

    if (snapshot.empty) {
      console.log(`User not found: ${email}`);
      return;
    }

    const user = snapshot.docs[0].data();
    const uid = snapshot.docs[0].id;

    console.log(`\n=== USER: ${email} ===`);
    console.log(`UID: ${uid}`);
    console.log(`Username: ${user.username}`);
    console.log(`\n📋 All Visibility/Search Related Fields:\n`);

    const fields = [
      'isAdmin',
      'disabled',
      'accountStatus',
      'status',
      'hidden',
      'isHidden',
      'testAccount',
      'internalAccount',
      'archived',
    #!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccoIn
const admin = reqndeconst serviceAccount = require('./servi'r
admin.initializeApp({
  credential: admin.credential.c =>  credential: admine =});

const db = admin.firestore();

async function   
cif 
async function checkUser(em{
   try {
    const snapshot = awa      cold}: ${JSON.stringify(value).sub      .where('email', '==        .get();

    if (snapshot.e c
    if (sna${f      console.log(`User         return;
    }

    const user = snapshon?   }

    cro
    St    const uid = snapsting?.verificationSta
    console.log(`\n
    console.log(
    console.log(`UID: ${uid}`);
    consolere    console.log(`Username: ${u      console.log(`\n📋 All Visibility/Searchch
    const fields = [e.error('Error:', error.message);
  } finally {      'isAdmin',
  p(      'disabled
}      'accountStpr      'status',
     us      'hiddepp@g      'isHiddeck      'testAccouh(      '.error);
