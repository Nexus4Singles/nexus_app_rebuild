const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
const readline = require('readline');

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

// Create readline interface for user input
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

function question(query) {
  return new Promise((resolve) => {
    rl.question(query, resolve);
  });
}

async function interactiveSetup() {
  try {
    console.log('\n🚀 Nexus App Update Configuration Setup\n');
    console.log('This wizard will help you set up the app update configuration in Firestore.\n');

    // Get version
    const latestVersion = await question('📌 Enter the latest app version (e.g., 2.1.0): ');
    if (!latestVersion.trim()) {
      console.error('❌ Version is required');
      process.exit(1);
    }

    // Get changes summary
    const changesSummary = await question('📝 Enter a brief change summary (e.g., Bug fixes and new features): ');
    if (!changesSummary.trim()) {
      console.error('❌ Changes summary is required');
      process.exit(1);
    }

    // Get iOS URL
    const iosUrl = await question('🍎 Enter iOS App Store URL (or press Enter to skip): ');

    // Get Android URL
    const androidUrl = await question('🤖 Enter Android Google Play URL (or press Enter to skip): ');

    rl.close();

    // Validate at least one store URL
    if (!iosUrl.trim() && !androidUrl.trim()) {
      console.error('❌ At least one store URL is required');
      process.exit(1);
    }

    const config = {
      latestVersion: latestVersion.trim(),
      releaseDate: admin.firestore.Timestamp.now(),
      changesSummary: changesSummary.trim(),
      storeUrl: {
        ...(iosUrl.trim() && { ios: iosUrl.trim() }),
        ...(androidUrl.trim() && { android: androidUrl.trim() }),
      },
    };

    console.log('\n📋 Configuration to be saved:\n');
    console.log('  Version:', config.latestVersion);
    console.log('  Changes:', config.changesSummary);
    if (config.storeUrl.ios) console.log('  iOS Store:', config.storeUrl.ios);
    if (config.storeUrl.android) console.log('  Android Store:', config.storeUrl.android);

    const confirm = await new Promise((resolve) => {
      rl.resume();
      rl.question('\n✅ Save this configuration? (yes/no): ', (answer) => {
        rl.close();
        resolve(answer.toLowerCase() === 'yes' || answer.toLowerCase() === 'y');
      });
    });

    if (!confirm) {
      console.log('❌ Setup cancelled');
      process.exit(0);
    }

    // Save to Firestore
    await db.collection('config').doc('appUpdate').set(config, { merge: true });

    console.log('\n✅ App update configuration saved successfully!\n');
    console.log('🎉 Users will now be prompted to update to version', config.latestVersion);
    console.log('\n✨ Next steps:');
    console.log('1. Release version', config.latestVersion, 'to the app stores');
    console.log('2. Wait for users to update their apps');
    console.log('3. Users will see the update modal on their next app launch\n');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error setting up configuration:', error.message);
    rl.close();
    process.exit(1);
  }
}

// Run setup
interactiveSetup();
