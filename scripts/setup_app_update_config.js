
const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin SDK
// Accepts both serviceAccountKey.json and serviceAccount.json
try {
  let serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  
  // If no env variable, check project root for either filename
  if (!serviceAccountPath) {
    const keyPath1 = path.join(__dirname, '..', 'serviceAccountKey.json');
    const keyPath2 = path.join(__dirname, '..', 'serviceAccount.json');
    
    if (fs.existsSync(keyPath1)) {
      serviceAccountPath = keyPath1;
    } else if (fs.existsSync(keyPath2)) {
      serviceAccountPath = keyPath2;
    }
  }

  if (serviceAccountPath && fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  } else {
    // If no service account file, try using Application Default Credentials
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  }
} catch (error) {
  console.error('❌ Firebase initialization error:', error.message);
  console.error('\nMake sure to either:');
  console.error('1. Set GOOGLE_APPLICATION_CREDENTIALS environment variable, or');
  console.error('2. Place serviceAccountKey.json or serviceAccount.json in project root');
  process.exit(1);
}

const db = admin.firestore();

// Configuration
const APP_UPDATE_CONFIG = {
  latestVersion: '2.0.2',
  releaseDate: admin.firestore.Timestamp.now(),
  changesSummary: 'Unified iOS and Android baseline release with enhanced chat features (3-user free tier) and app update notification system',
  storeUrl: {
    ios: 'https://apps.apple.com/ng/app/nexus-2-0/id6587567583',
    android: 'https://play.google.com/store/apps/details?id=com.nexusapptest.app',
  },
};

async function setupAppUpdateConfig() {
  try {
    console.log('📝 Setting up app update configuration...\n');

    const docRef = db.collection('config').doc('appUpdate');

    // Check if document exists
    const docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      console.log('ℹ️  Document already exists. Updating...');
      console.log('Current data:', docSnapshot.data());
    } else {
      console.log('✨ Creating new document...');
    }

    // Set or update the document
    await docRef.set(APP_UPDATE_CONFIG, { merge: true });

    console.log('\n✅ App update configuration saved successfully!\n');
    console.log('📋 Configuration details:');
    console.log('  Version:', APP_UPDATE_CONFIG.latestVersion);
    console.log('  Changes:', APP_UPDATE_CONFIG.changesSummary);
    console.log('  iOS Store:', APP_UPDATE_CONFIG.storeUrl.ios);
    console.log('  Android Store:', APP_UPDATE_CONFIG.storeUrl.android);
    console.log('\n✅ Users will now be prompted to update to version', APP_UPDATE_CONFIG.latestVersion);

    process.exit(0);
  } catch (error) {
    console.error('❌ Error setting up configuration:', error.message);
    console.error('\nStack trace:', error);
    process.exit(1);
  }
}

// Run setup
setupAppUpdateConfig();
