#!/usr/bin/env node

/**
 * ADMIN ACCOUNT WIPE SCRIPT
 * 
 * Completely removes a user account from the system, including:
 * - Firestore user document and all subcollections
 * - Firebase Authentication user
 * - Removes from admin review queue
 * 
 * USAGE:
 *   node wipe-user.js <email1> [email2] [email3] ...
 * 
 * EXAMPLES:
 *   node wipe-user.js user@example.com
 *   node wipe-user.js user1@example.com user2@example.com user3@example.com
 * 
 * REQUIREMENTS:
 *   - serviceAccount.json in project root
 *   - Firebase Admin SDK installed
 */

const admin = require('firebase-admin');
const path = require('path');
const readline = require('readline');

const emails = process.argv.slice(2);

if (emails.length === 0) {
  console.error('❌ Usage: node wipe-user.js <email1> [email2] [email3] ...');
  console.error('   Example: node wipe-user.js user1@example.com user2@example.com');
  process.exit(1);
}

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '../serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

async function deleteAllSubcollections(docRef) {
  const collections = await docRef.listCollections();
  for (const collection of collections) {
    const snapshot = await collection.get();
    for (const doc of snapshot.docs) {
      await deleteAllSubcollections(doc.ref);
      await doc.ref.delete();
    }
  }
}

async function wipeUser(email) {
  const normalizedEmail = email.trim().toLowerCase();
  
  try {
    console.log(`\n📧 Step 1: Finding user with email: ${normalizedEmail}`);
    
    // Find user by email
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('email', '==', normalizedEmail)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.error(`❌ User not found with email: ${normalizedEmail}`);
      return { success: false, email: normalizedEmail, reason: 'User not found' };
    }

    const userDoc = usersSnapshot.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();

    console.log(`✅ User found!`);
    console.log(`   UID: ${userId}`);
    console.log(`   Email: ${userData.email}`);
    console.log(`   Username: ${userData.username || 'N/A'}`);
    console.log(`   Name: ${userData.name || 'N/A'}`);

    // Step 2: Delete all subcollections
    console.log(`⏳ Step 2: Deleting subcollections...`);
    await deleteAllSubcollections(userDoc.ref);
    console.log(`✅ Subcollections deleted`);

    // Step 3: Delete the user document
    console.log(`⏳ Step 3: Deleting Firestore user document...`);
    await userDoc.ref.delete();
    console.log(`✅ Firestore user document deleted`);
    console.log(`   (Firebase Auth user will be deleted automatically by cloud function)\n`);

    // Step 4: Try to delete from Auth as backup
    try {
      console.log(`⏳ Step 4: Deleting from Firebase Auth (backup)...`);
      await admin.auth().deleteUser(userId);
      console.log(`✅ Firebase Auth user deleted\n`);
    } catch (authError) {
      if (authError.code === 'auth/user-not-found') {
        console.log(`ℹ️  Firebase Auth user already deleted\n`);
      } else {
        console.warn(`⚠️  Failed to delete Auth user: ${authError.message}\n`);
      }
    }

    console.log(`✅ Account completely wiped: ${normalizedEmail}`);
    return { success: true, email: normalizedEmail, userId };

  } catch (error) {
    console.error(`\n❌ Error wiping user ${normalizedEmail}:`, error.message);
    return { success: false, email: normalizedEmail, reason: error.message };
  }
}

async function main() {
  console.log('\n' + '='.repeat(70));
  console.log(`🗑️  ADMIN ACCOUNT WIPE SCRIPT`);
  console.log('='.repeat(70));
  
  console.log(`\n⚠️  WARNING: This will PERMANENTLY delete ${emails.length} account(s):`);
  emails.forEach(e => console.log(`   - ${e}`));
  
  const confirm = await question('\n❓ Type "DELETE" to confirm: ');
  
  if (confirm !== 'DELETE') {
    console.log('❌ Cancelled. No accounts deleted.\n');
    rl.close();
    process.exit(0);
  }

  console.log('\n' + '='.repeat(70));
  console.log(`Wiping ${emails.length} account(s)...`);
  console.log('='.repeat(70));

  const results = [];
  for (const email of emails) {
    const result = await wipeUser(email);
    results.push(result);
  }

  // Summary
  console.log('\n' + '='.repeat(70));
  console.log(`📊 SUMMARY`);
  console.log('='.repeat(70));
  
  const successful = results.filter(r => r.success);
  const failed = results.filter(r => !r.success);

  console.log(`\n✅ Successful: ${successful.length}`);
  successful.forEach(r => console.log(`   - ${r.email} (UID: ${r.userId})`));

  if (failed.length > 0) {
    console.log(`\n❌ Failed: ${failed.length}`);
    failed.forEach(r => console.log(`   - ${r.email}: ${r.reason}`));
  }

  console.log('\n' + '='.repeat(70) + '\n');

  rl.close();
  process.exit(0);
}

main().catch(error => {
  console.error('Fatal error:', error);
  rl.close();
  process.exit(1);
});
