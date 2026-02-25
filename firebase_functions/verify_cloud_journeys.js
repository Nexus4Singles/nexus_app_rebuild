#!/usr/bin/env node

/**
 * VERIFY CLOUD JOURNEY SYSTEM
 * Run after deploying cloud functions to test endpoints
 */

const https = require('https');

const BASE_URL = 'https://us-central1-nexus-app-v2.cloudfunctions.net';
const TESTS = [
  {
    name: 'List married journeys',
    url: `${BASE_URL}/listJourneys?category=married`,
    method: 'GET',
  },
  {
    name: 'Fetch married_journey_01',
    url: `${BASE_URL}/getJourney?category=married&journeyId=married_journey_01_communication_conflict`,
    method: 'GET',
  },
  {
    name: 'List divorced journeys',
    url: `${BASE_URL}/listJourneys?category=divorced`,
    method: 'GET',
  },
  {
    name: 'List widowed journeys',
    url: `${BASE_URL}/listJourneys?category=widowed`,
    method: 'GET',
  },
  {
    name: 'List singles journeys',
    url: `${BASE_URL}/listJourneys?category=singles`,
    method: 'GET',
  },
];

function makeRequest(url, method = 'GET') {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      method,
      timeout: 10000,
    };

    const req = https.request(options, res => {
      let data = '';
      res.on('data', chunk => (data += chunk));
      res.on('end', () => {
        try {
          resolve({
            status: res.statusCode,
            data: JSON.parse(data),
          });
        } catch {
          resolve({
            status: res.statusCode,
            data: data,
          });
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
    req.end();
  });
}

async function runTests() {
  console.log('\n' + '='.repeat(70));
  console.log('🧪 CLOUD JOURNEY SYSTEM VERIFICATION');
  console.log('='.repeat(70));
  console.log(`\n📍 Testing: ${BASE_URL}\n`);

  let passed = 0;
  let failed = 0;

  for (const test of TESTS) {
    try {
      const result = await makeRequest(test.url, test.method);
      const success = result.status === 200;

      if (success) {
        const count = result.data.count || result.data.journeys?.length || 0;
        console.log(`✅ ${test.name}`);
        console.log(`   → Status: ${result.status}, Items: ${count}\n`);
        passed++;
      } else {
        console.log(`❌ ${test.name}`);
        console.log(`   → Status: ${result.status}`);
        console.log(`   → Error: ${result.data.error || 'Unknown error'}\n`);
        failed++;
      }
    } catch (error) {
      console.log(`❌ ${test.name}`);
      console.log(`   → ${error.message}\n`);
      failed++;
    }
  }

  console.log('='.repeat(70));
  console.log(`📊 Results: ${passed} passed, ${failed} failed`);
  console.log('='.repeat(70));

  if (failed === 0) {
    console.log('\n✅ All tests passed! Cloud functions are working.\n');
    process.exit(0);
  } else {
    console.log('\n❌ Some tests failed. Check Firebase deployment.\n');
    process.exit(1);
  }
}

runTests().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
