#!/usr/bin/env node

/**
 * Comprehensive journey upload verification script
 * - Lists all journeys locally
 * - Lists all journeys in cloud storage
 * - Reports missing journeys
 * - Verifies fallback assets are present
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

// Journey mapping from config
const journeyMappings = {
  singles: 21,
  married: 18,
  divorced: 16,
  widowed: 10
};

const expectedTotal = Object.values(journeyMappings).reduce((a, b) => a + b, 0);

async function verifyAllJourneys() {
  console.log('🔍 COMPREHENSIVE JOURNEY VERIFICATION\n');
  console.log(`📊 Expected Total: ${expectedTotal} journeys`);
  console.log(`   - Singles: ${journeyMappings.singles}`);
  console.log(`   - Married: ${journeyMappings.married}`);
  console.log(`   - Divorced: ${journeyMappings.divorced}`);
  console.log(`   - Widowed: ${journeyMappings.widowed}\n`);

  try {
    // 1. Check local journeys
    console.log('📁 CHECKING LOCAL JOURNEYS');
    const localJourneys = checkLocalJourneys();
    console.log(`   ✅ Found ${localJourneys.total} local files\n`);

    // 2. Check cloud journeys
    console.log('☁️  CHECKING CLOUD STORAGE');
    const cloudJourneys = await checkCloudJourneys();
    console.log(`   ✅ Found ${cloudJourneys.total} in cloud\n`);

    // 3. Compare and report
    console.log('📋 VERIFICATION RESULTS');
    const results = compareJourneys(localJourneys, cloudJourneys);
    
    // Check fallback assets
    console.log('\n📦 CHECKING FALLBACK ASSETS');
    const fallbackAssets = checkFallbackAssets();
    
    // Final summary
    console.log('\n' + '='.repeat(60));
    console.log('✅ VERIFICATION COMPLETE');
    console.log('='.repeat(60));
    console.log(`
Summary:
- Expected journeys: ${expectedTotal}
- Local journeys: ${localJourneys.total}
- Cloud journeys: ${cloudJourneys.total}
- Missing in cloud: ${results.missing.length}
- Fallback assets: ${fallbackAssets.hasAssets ? '✅ Present' : '❌ Missing'}
    `);

    if (results.missing.length > 0) {
      console.log('⚠️  Missing cloud journeys:');
      results.missing.forEach(j => console.log(`   - ${j}`));
    } else {
      console.log('✅ All journeys present in cloud!');
    }

    if (results.extra.length > 0) {
      console.log('\n⚠️  Extra journeys in cloud (not in mapping):');
      results.extra.forEach(j => console.log(`   - ${j}`));
    }

  } catch (error) {
    console.error('❌ Verification failed:', error.message);
    process.exit(1);
  }
}

function checkLocalJourneys() {
  const journeysDir = path.join(__dirname, 'assets/config/journeys');
  const localJourneys = {
    by_category: {},
    total: 0,
    files: []
  };

  for (const [category, count] of Object.entries(journeyMappings)) {
    const categoryPath = path.join(journeysDir, category === 'singles' ? 'singles journeys' : category === 'married' ? 'married journeys' : category === 'divorced' ? 'divorced journeys' : 'widowed journeys');
    
    if (!fs.existsSync(categoryPath)) {
      console.log(`   ⚠️  Missing local folder: ${categoryPath}`);
      localJourneys.by_category[category] = { found: 0, expected: count };
      continue;
    }

    const files = fs.readdirSync(categoryPath).filter(f => f.endsWith('.json'));
    console.log(`   ${category}: ${files.length}/${count} files`);
    localJourneys.by_category[category] = { found: files.length, expected: count };
    localJourneys.total += files.length;
      // Remove .json extension for comparison with cloud
      localJourneys.files.push(...files.map(f => `${category}/${f.replace('.json', '')}`));
  }

  return localJourneys;
}

async function checkCloudJourneys() {
  const cloudJourneys = {
    by_category: {},
    total: 0,
    files: []
  };

  for (const category of Object.keys(journeyMappings)) {
    try {
      const [files] = await bucket.getFiles({
        prefix: `journeys/${category}/`,
        autoPaginate: true
      });

      // Filter only .json files and get their IDs (filename without extension)
      const jsonFiles = files
        .filter(f => f.name.endsWith('.json'))
        .map(f => path.basename(f.name, '.json'));

      console.log(`   ${category}: ${jsonFiles.length} files`);
      cloudJourneys.by_category[category] = jsonFiles.length;
      cloudJourneys.total += jsonFiles.length;
      cloudJourneys.files.push(...jsonFiles.map(f => `${category}/${f}`));
    } catch (error) {
      console.log(`   ${category}: ❌ Error - ${error.message}`);
      cloudJourneys.by_category[category] = 0;
    }
  }

  return cloudJourneys;
}

function compareJourneys(local, cloud) {
  // Normalize for comparison (remove .json from local for comparison)
  const localNormalized = local.files.map(f => f.replace('.json', ''));
  const cloudNormalized = cloud.files;

  const localSet = new Set(localNormalized);
  const cloudSet = new Set(cloudNormalized);

  const missing = localNormalized.filter(f => !cloudSet.has(f));
  const extra = cloudNormalized.filter(f => !localSet.has(f));

  return { missing, extra };
}

function checkFallbackAssets() {
  const assetsDir = path.join(__dirname, 'lib/assets');
  let hasAssets = false;
  
  // Check if assets are bundled in the app
  if (fs.existsSync(assetsDir)) {
    hasAssets = true;
  }

  // Also check if journeys have local copies
  const localJourneysDir = path.join(__dirname, 'assets/config/journeys');
  const hasLocalJourneys = fs.existsSync(localJourneysDir);

  console.log(`   Bundled assets: ${hasAssets ? '✅' : '⚠️'}`);
  console.log(`   Local journeys directory: ${hasLocalJourneys ? '✅' : '❌'}`);
  
  return { hasAssets: hasAssets || hasLocalJourneys };
}

verifyAllJourneys();
