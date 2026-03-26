const https = require('https');

const apiKey = process.env.REVENUECAT_API_KEY;

async function queryRevenueCAT(userId) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.revenuecat.com',
      port: 443,
      path: `/v1/subscribers/${userId}`,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      timeout: 10000,
    };

    const req = https.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        try {
          if (res.statusCode === 404) {
            resolve({ found: false, statusCode: 404 });
            return;
          }
          if (res.statusCode !== 200) {
            resolve({ statusCode: res.statusCode, error: data });
            return;
          }
          const customerData = JSON.parse(data);
          resolve({ found: true, statusCode: 200, customerData });
        } catch (err) {
          resolve({ error: 'Parse error', details: err.message });
        }
      });
    });

    req.on('error', (error) => {
      resolve({ error: 'Request failed', details: error.message });
    });

    req.on('timeout', () => {
      req.destroy();
      resolve({ error: 'Timeout' });
    });

    req.end();
  });
}

async function compareTwoUsers() {
  console.log(`\n=== COMPARING TWO ANDROID USERS ===\n`);

  // Current issue
  const user1Id = 'NkQa8IaOTlXgqTQGaukysv2q0jk2';
  console.log(`User 1: ${user1Id}`);
  const result1 = await queryRevenueCAT(user1Id);
  if (result1.found) {
    const appUserId = result1.customerData.subscriber.app_user_id;
    const origAppUserId = result1.customerData.subscriber.original_app_user_id;
    console.log(`  - app_user_id: ${appUserId || 'NOT SET'}`);
    console.log(`  - original: ${origAppUserId}`);
  } else {
    console.log(`  - NOT FOUND in RevenueCat`);
  }

  // Previous issue
  const user2Id = '356Vl7KrMUTboKzkAMIWp1aefcn2';
  console.log(`\nUser 2: ${user2Id}`);
  const result2 = await queryRevenueCAT(user2Id);
  if (result2.found) {
    const appUserId = result2.customerData.subscriber.app_user_id;
    const origAppUserId = result2.customerData.subscriber.original_app_user_id;
    console.log(`  - app_user_id: ${appUserId || 'NOT SET'}`);
    console.log(`  - original: ${origAppUserId}`);
  } else {
    console.log(`  - NOT FOUND in RevenueCat`);
  }

  console.log(`\n=== ANALYSIS ===`);
  if (result1.found && result2.found) {
    const user1AppId = result1.customerData.subscriber.app_user_id;
    const user2AppId = result2.customerData.subscriber.app_user_id;
    
    if (!user1AppId && !user2AppId) {
      console.log('✅ PATTERN CONFIRMED: Both users have app_user_id NOT SET');
      console.log('\nRoot Cause: App is using anonymous RevenueCat IDs');
      console.log('instead of logging in with Firebase UIDs.\n');
      console.log('Issue: revenueCatWebhook tries to find user by app_user_id,');
      console.log('but that\'s set to $RCAnonymousID instead of Firebase UID,');
      console.log('so webhook silently skips these users.');
    } else {
      console.log('NOT identical pattern');
    }
  }
}

if (!apiKey) {
  console.error('❌ REVENUECAT_API_KEY not set');
  process.exit(1);
}

compareTwoUsers().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
