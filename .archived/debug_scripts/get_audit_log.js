#!/usr/bin/env node

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, 'serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

async function getAuditLog(email) {
  try {
    const db = admin.firestore();
    
    console.log(`\n🔍 Looking up user: ${email}`);
    
    // Find user by email
    const usersSnapshot = await db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.log(`❌ No user found with email: ${email}\n`);
      process.exit(1);
    }

    const userDoc = usersSnapshot.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();

    console.log(`✅ Found user: ${userId}`);
    console.log(`   Name: ${userData.username || userData.name}`);
    console.log(`   Email: ${userData.email}`);

    // Get audit log
    console.log(`\n📜 Fetching audit log...`);
    const auditSnapshot = await db
      .collection('users')
      .doc(userId)
      .collection('auditLog')
      .orderBy('timestamp', 'desc')
      .limit(20)
      .get();

    if (auditSnapshot.empty) {
      console.log(`❌ No audit log entries found`);
      process.exit(0);
    }

    console.log(`\n📋 Last 20 Audit Log Entries (newest first):\n`);

    let verificationRelated = [];
    
    auditSnapshot.forEach((doc, index) => {
      const data = doc.data();
      const timestamp = data.timestamp ? new Date(data.timestamp.toDate()).toLocaleString() : 'N/A';
      const action = data.action || 'UNKNOWN';
      
      console.log(`${index + 1}. [${timestamp}]`);
      console.log(`   Action: ${action}`);
      console.log(`   Details:`);
      
      // Show all fields
      for (const [key, value] of Object.entries(data)) {
        if (key !== 'timestamp' && key !== 'action') {
          if (typeof value === 'object' && value !== null && value.toDate) {
            console.log(`     - ${key}: ${new Date(value.toDate()).toLocaleString()}`);
          } else {
            console.log(`     - ${key}: ${JSON.stringify(value)}`);
          }
        }
      }
      
      // Track verification-related entries
      if (action.toLowerCase().includes('verif') || action.toLowerCase().includes('dating')) {
        verificationRelated.push({
          index: index + 1,
          action,
          timestamp,
          data
        });
      }
      
      console.log('');
    });

    if (verificationRelated.length > 0) {
      console.log(`\n🔍 VERIFICATION-RELATED ENTRIES:\n`);
      verificationRelated.forEach(entry => {
        console.log(`Entry #${entry.index}: ${entry.action} at ${entry.timestamp}`);
        if (entry.data.verificationStatus) {
          console.log(`   Status: ${entry.data.verificationStatus}`);
        }
      });
    }

    process.exit(0);
  } catch (error) {
    console.error(`\n❌ Error: ${error.message}`);
    console.error(error);
    process.exit(1);
  }
}

const email = process.argv[2];

if (!email) {
  console.error(`
Usage: node get_audit_log.js <email>

Arguments:
  <email>  User email (e.g., arc.prosperchukwuka@gmail.com)

Example:
  node get_audit_log.js arc.prosperchukwuka@gmail.com
  `);
  process.exit(1);
}

getAuditLog(email);
