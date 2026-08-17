const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

function readPubspecVersion() {
  const pubspec = fs.readFileSync(path.join(__dirname, '..', 'pubspec.yaml'), 'utf8');
  const match = pubspec.match(/^version:\s*([^+\s]+)/m);
  return match ? match[1] : null;
}

function resolveVersion() {
  const version = (process.env.RELEASE_VERSION || process.env.GITHUB_REF_NAME || readPubspecVersion()).replace(/^v/, '');
  if (!version || !/^\d+\.\d+\.\d+$/.test(version)) {
    throw new Error(`Invalid release version: ${version || '(missing)'}`);
  }
  return version;
}

function initializeFirebase() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    admin.initializeApp({
      credential: admin.credential.cert(
        JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON),
      ),
    });
    return;
  }

  const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.join(__dirname, '..', 'serviceAccount.json');
  if (fs.existsSync(credentialsPath)) {
    admin.initializeApp({ credential: admin.credential.cert(require(credentialsPath)) });
    return;
  }
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
}

async function main() {
  const latestVersion = resolveVersion();
  const summary = process.env.RELEASE_SUMMARY || `Nexus update ${latestVersion}`;
  const config = {
    latestVersion,
    releaseDate: admin.firestore.Timestamp.now(),
    changesSummary: summary,
    storeUrl: {
      ios: process.env.IOS_STORE_URL || 'https://apps.apple.com/ng/app/nexus-2-0/id6587567583',
      android: process.env.ANDROID_STORE_URL || 'https://play.google.com/store/apps/details?id=com.nexusapptest.app',
    },
  };

  if (process.env.DRY_RUN === 'true') {
    console.log(JSON.stringify(config, null, 2));
    return;
  }

  initializeFirebase();
  await admin.firestore().collection('config').doc('appUpdate').set(config, { merge: true });
  console.log(`Published config/appUpdate for version ${latestVersion}`);
}

main().catch((error) => {
  console.error(`Failed to publish app update config: ${error.message}`);
  process.exitCode = 1;
});
