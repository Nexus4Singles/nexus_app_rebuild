#!/usr/bin/env node

/**
 * JOURNEY MIGRATION SCRIPT
 * 
 * Uploads all local journey JSON files to Firestore for cloud serving.
 * Run once to seed initial data, then updates happen via cloud functions.
 * 
 * Usage:
 *   node migrate_journeys_to_firestore.js
 * 
 * Prerequisites:
 *   1. Firebase Admin SDK initialized (firebase_functions/index.js)
 *   2. Service account key in GOOGLE_APPLICATION_CREDENTIALS environment
 *   3. Firestore database created in Firebase project
 * 
 * What it does:
 *   - Reads all journey JSON files from assets/config/journeys/
 *   - Creates Firestore structure: journeys/{category}/files/{journeyId}
 *   - Stores full content + metadata (version, title, timestamps)
 *   - Preserves original file structure for rollback
 *   - Logs results for verification
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
// Make sure GOOGLE_APPLICATION_CREDENTIALS env var points to service account key
if (!admin.apps.length) {
  try {
    admin.initializeApp({
      projectId: process.env.FIREBASE_PROJECT_ID || 'nexus-app-v2',
    });
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Admin SDK');
    console.error('   Ensure GOOGLE_APPLICATION_CREDENTIALS is set');
    process.exit(1);
  }
}

const db = admin.firestore();
const journeysDir = path.join(__dirname, '../assets/config/journeys');

// Journey categories to migrate
const categories = ['singles', 'married', 'divorced', 'widowed'];

// Track migration progress
const results = {
  startTime: new Date(),
  categoriesProcessed: {},
  totalFiles: 0,
  totalUploaded: 0,
  errors: [],
};

/**
 * Extract journey number from filename
 * E.g., 'married_journey_01_communication_conflict.json' -> 1
 */
function extractJourneyNumber(filename) {
  const match = filename.match(/_journey_(\d+)_/);
  return match ? parseInt(match[1], 10) : 0;
}

/**
 * Migrate all journeys for a single category
 */
async function migrateCategory(category) {
  console.log(`\n📁 Processing category: ${category.toUpperCase()}`);
  console.log('─'.repeat(60));

  const categoryDir = path.join(journeysDir, `${category} journeys`);

  // Verify directory exists
  if (!fs.existsSync(categoryDir)) {
    console.warn(`⚠️  Directory not found: ${categoryDir}`);
    return 0;
  }

  // Find all journey files
  const files = fs
    .readdirSync(categoryDir)
    .filter(f => f.endsWith('.json') && f.startsWith(`${category}_journey_`))
    .sort((a, b) => {
      const numA = extractJourneyNumber(a);
      const numB = extractJourneyNumber(b);
      return numA - numB;
    });

  if (files.length === 0) {
    console.warn(`⚠️  No journey files found in ${categoryDir}`);
    return 0;
  }

  console.log(`✓ Found ${files.length} journey files`);
  results.categoriesProcessed[category] = {
    fileCount: files.length,
    uploaded: 0,
    failed: 0,
    files: [],
  };

  // Upload each journey file
  let uploadedCount = 0;
  for (const file of files) {
    const filePath = path.join(categoryDir, file);
    const journeyId = file.replace('.json', '');

    try {
      // Read JSON file
      const rawContent = fs.readFileSync(filePath, 'utf8');
      const content = JSON.parse(rawContent);

      // Extract metadata
      const title = content.title || 'Untitled Journey';
      const journeyNumber = extractJourneyNumber(file);

      // Save to Firestore
      await db
        .collection('journeys')
        .doc(category)
        .collection('files')
        .doc(journeyId)
        .set({
          journeyId,
          category,
          content,
          title,
          journeyNumber,
          version: 1,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          uploadedAt: new Date().toISOString(),
          sourceFile: filePath,
          contentSize: rawContent.length,
          activityCount: content.activities?.length || 0,
        });

      console.log(
        `  ✓ ${journeyId.padEnd(55)} (${(rawContent.length / 1024).toFixed(1)}KB)`
      );

      uploadedCount++;
      results.categoriesProcessed[category].uploaded++;
      results.categoriesProcessed[category].files.push({
        journeyId,
        status: 'uploaded',
        size: rawContent.length,
      });
    } catch (error) {
      console.error(`  ✗ ${journeyId}`);
      console.error(`    Error: ${error.message}`);
      results.errors.push({
        file,
        category,
        error: error.message,
      });
      results.categoriesProcessed[category].failed++;
      results.categoriesProcessed[category].files.push({
        journeyId,
        status: 'failed',
        error: error.message,
      });
    }
  }

  console.log(
    `\n  Summary: ${uploadedCount}/${files.length} uploaded successfully`
  );
  return uploadedCount;
}

/**
 * Main migration process
 */
async function runMigration() {
  console.log('\n' + '='.repeat(60));
  console.log('🚀 JOURNEY MIGRATION TO FIRESTORE');
  console.log('='.repeat(60));
  console.log(`📍 Source: ${journeysDir}`);
  console.log(`🔥 Firebase Project: ${process.env.FIREBASE_PROJECT_ID || 'nexus-app-v2'}`);
  console.log('');

  try {
    // Migrate each category
    for (const category of categories) {
      const count = await migrateCategory(category);
      results.totalUploaded += count;
    }

    // Summary report
    console.log('\n' + '='.repeat(60));
    console.log('📊 MIGRATION SUMMARY');
    console.log('='.repeat(60));

    console.log('\nUploaded by category:');
    for (const [category, data] of Object.entries(
      results.categoriesProcessed
    )) {
      const status =
        data.uploaded === data.fileCount
          ? '✅'
          : data.uploaded === 0
          ? '❌'
          : '⚠️ ';
      console.log(
        `  ${status} ${category.padEnd(12)}: ${data.uploaded}/${data.fileCount}`
      );
    }

    console.log(`\n📈 Total: ${results.totalUploaded} files uploaded`);

    if (results.errors.length > 0) {
      console.log(`\n❌ Errors encountered: ${results.errors.length}`);
      results.errors.forEach(err => {
        console.log(`   - ${err.category}/${err.file}: ${err.error}`);
      });
    }

    // Duration
    const duration =
      (new Date().getTime() - results.startTime.getTime()) / 1000;
    console.log(`\n✓ Migration completed in ${duration.toFixed(1)}s`);

    // Next steps
    console.log('\n' + '='.repeat(60));
    console.log('🎯 NEXT STEPS');
    console.log('='.repeat(60));
    console.log(`
1. ✅ Journey files now live in Firestore
   - Structure: journeys/{category}/files/{journeyId}
   - Access via: CloudJourneyService

2. 🔄 Test the cloud functions:
   - GET /journeys?category=married&journeyId=married_journey_01_...
   - GET /journeys/list?category=married

3. 🎯 Update app to use cloud journeys:
   - Import CloudJourneyProvider
   - Replace local asset loading with ref.watch(cloudJourneyProvider(...))

4. 🔒 Admin operations:
   - Updates: POST /journeys/update (requires admin auth token)
   - History: GET /journeys/history?category=...&journeyId=...

5. 📝 Firestore Indexes (if needed):
   - journeys/{category}/files (ordered by journeyNumber)
   - journeys/{category}/history (ordered by version)
   Auto-created on first query - check Firestore console if slow.

6. 🚀 Deploy cloud functions:
   cd firebase_functions && npm run deploy
`);

    // Save detailed report
    const reportPath = path.join(__dirname, 'migration_report.json');
    fs.writeFileSync(reportPath, JSON.stringify(results, null, 2));
    console.log(`\n📋 Detailed report saved to: migration_report.json`);

    process.exit(results.errors.length === 0 ? 0 : 1);
  } catch (error) {
    console.error('\n❌ Fatal error during migration:');
    console.error(error);
    process.exit(1);
  }
}

// Run migration
runMigration().catch(error => {
  console.error('Unhandled error:', error);
  process.exit(1);
});
