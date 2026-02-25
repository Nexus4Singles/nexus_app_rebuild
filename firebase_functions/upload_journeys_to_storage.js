#!/usr/bin/env node

/**
 * Upload local journey JSONs to Firebase Storage
 * 
 * Usage:
 *   node upload_journeys_to_storage.js
 * 
 * This reads all journey JSONs from assets/config/journeys/ and uploads them to:
 *   gs://nexusgodlydating.appspot.com/journeys/{category}/{journeyId}.json
 * 
 * No Firestore seeding needed - just plain files in Storage
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase - use GOOGLE_APPLICATION_CREDENTIALS or default to ./serviceAccount.json
if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  const serviceAccountPath = path.join(__dirname, '../serviceAccount.json');
  if (fs.existsSync(serviceAccountPath)) {
    process.env.GOOGLE_APPLICATION_CREDENTIALS = serviceAccountPath;
  } else {
    console.error('❌ serviceAccount.json not found at', serviceAccountPath);
    console.error('   Set GOOGLE_APPLICATION_CREDENTIALS or place serviceAccount.json in project root');
    process.exit(1);
  }
}

admin.initializeApp({
  storageBucket: 'nexus-visibility-app.appspot.com'
});
const bucket = admin.storage().bucket();

const JOURNEY_DIR = path.join(__dirname, '../assets/config/journeys');

const CATEGORIES = ['singles journeys', 'married journeys', 'divorced journeys', 'widowed journeys'];
const CATEGORY_MAP = {
  'singles journeys': 'singles',
  'married journeys': 'married',
  'divorced journeys': 'divorced',
  'widowed journeys': 'widowed',
};

async function uploadAllJourneys() {
  console.log('📤 Uploading journeys to Firebase Storage...\n');

  let totalUploaded = 0;
  let totalFailed = 0;

  for (const dir of CATEGORIES) {
    const category = CATEGORY_MAP[dir];
    const folderPath = path.join(JOURNEY_DIR, dir);

    if (!fs.existsSync(folderPath)) {
      console.log(`⚠️  Folder not found: ${dir}`);
      continue;
    }

    const files = fs
      .readdirSync(folderPath)
      .filter(f => f.endsWith('.json'))
      .sort();

    console.log(`\n📂 ${category} (${files.length} files):`);

    for (const file of files) {
      const filePath = path.join(folderPath, file);
      const journeyId = file.replace('.json', '');

      try {
        const jsonContent = fs.readFileSync(filePath, 'utf8');
        const data = JSON.parse(jsonContent);

        // Upload to Storage at: journeys/{category}/{journeyId}.json
        const storagePath = `journeys/${category}/${journeyId}.json`;
        const destFile = bucket.file(storagePath);

        await destFile.save(JSON.stringify(data, null, 2), {
          metadata: {
            contentType: 'application/json',
            cacheControl: 'public, max-age=300',
          },
        });

        console.log(`  ✅ ${journeyId}`);
        totalUploaded++;
      } catch (error) {
        console.error(`  ❌ ${journeyId}: ${error.message}`);
        totalFailed++;
      }
    }
  }

  console.log(`\n${'='.repeat(60)}`);
  console.log(`📊 UPLOAD COMPLETE`);
  console.log(`  ✅ Uploaded: ${totalUploaded}`);
  console.log(`  ❌ Failed: ${totalFailed}`);
  console.log(`\n🎉 Journeys now live in Storage!`);
  console.log(`   Path: journeys/{category}/{journeyId}.json`);
  console.log(`   Access via: /getJourney?category={cat}&journeyId={id}`);
  console.log(`${'='.repeat(60)}\n`);
}

uploadAllJourneys().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
