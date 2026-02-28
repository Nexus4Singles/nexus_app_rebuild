#!/usr/bin/env node

/**
 * Upload a single journey file to Firebase Storage
 * Usage: node upload_single_journey.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase
if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  const serviceAccountPath = path.join(__dirname, './serviceAccount.json');
  if (fs.existsSync(serviceAccountPath)) {
    process.env.GOOGLE_APPLICATION_CREDENTIALS = serviceAccountPath;
  } else {
    console.error('❌ serviceAccount.json not found');
    process.exit(1);
  }
}

admin.initializeApp({
  storageBucket: 'nexus-visibility-app.appspot.com'
});

const bucket = admin.storage().bucket();

async function uploadSingleJourney() {
  try {
    const journeyPath = path.join(
      __dirname,
      'assets/config/journeys/widowed journeys/widowed_journey_06_rediscovering_identity.json'
    );

    if (!fs.existsSync(journeyPath)) {
      console.error('❌ File not found:', journeyPath);
      process.exit(1);
    }

    const fileContent = fs.readFileSync(journeyPath);
    const fileName = 'widowed_journey_06_rediscovering_identity';
    const storagePath = `journeys/widowed/${fileName}.json`;

    console.log('📤 Uploading widowed journey 6...');
    console.log(`   Local: ${journeyPath}`);
    console.log(`   Cloud: gs://nexus-visibility-app.appspot.com/${storagePath}\n`);

    await bucket.file(storagePath).save(fileContent, {
      metadata: {
        contentType: 'application/json',
      },
    });

    console.log(`✅ Successfully uploaded: ${fileName}`);
    console.log('   The changes should now be visible in the app!');
  } catch (error) {
    console.error('❌ Upload failed:', error.message);
    process.exit(1);
  }
}

uploadSingleJourney();
