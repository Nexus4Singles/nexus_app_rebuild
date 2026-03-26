#!/usr/bin/env node

/**
 * ADMIN COACH APPLICATIONS WIPE SCRIPT
 * 
 * Completely removes all coach applications from the review queue
 * 
 * USAGE:
 *   node wipe-coach-applications.js [--status <status>] [--count-only]
 * 
 * OPTIONS:
 *   --status <status>     Filter by status (pending, approved, rejected, all). Default: all
 *   --count-only          Just count applications, don't delete
 * 
 * EXAMPLES:
 *   node wipe-coach-applications.js                    # Wipe all applications
 *   node wipe-coach-applications.js --status pending   # Wipe only pending
 *   node wipe-coach-applications.js --count-only       # Count all applications
 * 
 * REQUIREMENTS:
 *   - serviceAccount.json in project root
 *   - Firebase Admin SDK installed
 */

const admin = require('firebase-admin');
const path = require('path');
const readline = require('readline');

// Parse command line arguments
const args = process.argv.slice(2);
let statusFilter = 'all';
let countOnly = false;
let confirmed = false;

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--status' && args[i + 1]) {
    statusFilter = args[i + 1];
    i++;
  }
  if (args[i] === '--count-only') {
    countOnly = true;
  }
  if (args[i] === '--confirmed') {
    confirmed = true;
  }
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

async function main() {
  console.log('\n' + '='.repeat(70));
  console.log(`🗑️  COACH APPLICATIONS WIPE SCRIPT`);
  console.log('='.repeat(70) + '\n');

  try {
    // Step 1: Query applications
    console.log(`📧 Step 1: Fetching coach applications (status filter: ${statusFilter})...`);
    
    let query = admin.firestore().collection('coachApplications');
    
    if (statusFilter !== 'all') {
      query = query.where('status', '==', statusFilter);
    }

    const snapshot = await query.get();
    const applications = snapshot.docs.map(doc => ({
      id: doc.id,
      data: doc.data()
    }));

    console.log(`✅ Found ${applications.length} application(s)\n`);

    if (applications.length === 0) {
      console.log('ℹ️  No applications to delete.\n');
      rl.close();
      process.exit(0);
    }

    // Display applications to be deleted
    console.log(`📋 Applications to be deleted:`);
    applications.forEach((app, i) => {
      console.log(`   ${i + 1}. ${app.data.fullName} (${app.data.email}) - Status: ${app.data.status}`);
    });
    console.log('');

    // If count-only, just exit
    if (countOnly) {
      console.log(`Total: ${applications.length} application(s)\n`);
      rl.close();
      process.exit(0);
    }

    // Step 2: Confirm deletion
    if (!confirmed) {
      console.log(`⚠️  WARNING: This will PERMANENTLY delete ${applications.length} application(s)!`);
      const confirm = await question('❓ Type "DELETE" to confirm: ');
      
      if (confirm !== 'DELETE') {
        console.log('❌ Cancelled. No applications deleted.\n');
        rl.close();
        process.exit(0);
      }
    }

    // Step 3: Delete applications
    console.log('\n' + '='.repeat(70));
    console.log(`Deleting ${applications.length} application(s)...`);
    console.log('='.repeat(70) + '\n');

    let successCount = 0;
    let failedCount = 0;
    const failed = [];

    for (let i = 0; i < applications.length; i++) {
      const app = applications[i];
      const progress = `[${i + 1}/${applications.length}]`;
      
      try {
        await admin.firestore()
          .collection('coachApplications')
          .doc(app.id)
          .delete();
        
        console.log(`${progress} ✅ Deleted: ${app.data.fullName} (${app.data.email})`);
        successCount++;
      } catch (error) {
        console.error(`${progress} ❌ Failed: ${app.data.fullName} - ${error.message}`);
        failed.push({ app, error: error.message });
        failedCount++;
      }
    }

    // Summary
    console.log('\n' + '='.repeat(70));
    console.log(`📊 SUMMARY`);
    console.log('='.repeat(70));
    
    console.log(`\n✅ Deleted: ${successCount}`);
    
    if (failedCount > 0) {
      console.log(`\n❌ Failed: ${failedCount}`);
      failed.forEach(f => {
        console.log(`   - ${f.app.data.fullName}: ${f.error}`);
      });
    }

    console.log(`\n📝 Total applications: ${applications.length}`);
    console.log('='.repeat(70) + '\n');

    if (rl) rl.close();
    process.exit(failedCount > 0 ? 1 : 0);

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.error(error);
    rl.close();
    process.exit(1);
  }
}

main();
