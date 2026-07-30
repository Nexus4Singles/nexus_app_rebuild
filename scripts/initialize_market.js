const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccount.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://nexus-project-c49a0.firebaseio.com"
  });
}

const db = admin.firestore();

async function initializeMarket(market = 'uk') {
  try {
    console.log(`🚀 Initializing market: ${market}...`);

    const marketRef = db.collection('markets').doc(market);
    const marketDoc = await marketRef.get();

    // Check if market already exists
    if (marketDoc.exists) {
      console.log(`⚠️  Market '${market}' already exists. Current data:`);
      console.log(JSON.stringify(marketDoc.data(), null, 2));
      return;
    }

    // Get country name
    const countryMap = {
      uk: 'United Kingdom',
      nigeria: 'Nigeria',
      ghana: 'Ghana',
    };

    const country = countryMap[market] || market;

    // Create market document with defaults
    const marketConfig = {
      country: country,
      phase: 'prelaunch',
      launchDate: null,
      approvedProfileCount: 0,
      gender: {
        male: 0,
        female: 0,
      },
      dailyNotificationTime: '09:00',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await marketRef.set(marketConfig);

    console.log(`✅ Market '${market}' initialized successfully!`);
    console.log('\n--- Market Configuration ---');
    console.log(JSON.stringify(marketConfig, null, 2));
    console.log('\n--- Next Steps ---');
    console.log('1. Verify in Firebase Console: Firestore Database > collections > markets > uk');
    console.log('2. Set up Cloud Scheduler for daily 14-day waitlist reminders');
    console.log('3. Test admin panel at /admin/market-launch');
    console.log('4. Create test users with countryOfResidence="United Kingdom"');
  } catch (error) {
    console.error('❌ Error initializing market:', error.message);
    process.exit(1);
  }
}

// Run script
const market = process.argv[2] || 'uk';
initializeMarket(market).then(() => {
  console.log('\n✨ Done!');
  process.exit(0);
});
