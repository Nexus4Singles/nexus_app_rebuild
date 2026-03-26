const https = require('https');

// RevenueCat API key - should be in environment or functions config
const apiKey = process.env.REVENUECAT_API_KEY;

if (!apiKey) {
  console.error('❌ REVENUECAT_API_KEY not set in .env or environment');
  process.exit(1);
}

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
            resolve({
              found: false,
              statusCode: 404,
              message: 'User not found in RevenueCat',
            });
            return;
          }

          if (res.statusCode !== 200) {
            resolve({
              statusCode: res.statusCode,
              error: data,
            });
            return;
          }

          const customerData = JSON.parse(data);
          resolve({
            found: true,
            statusCode: 200,
            customerData: customerData,
          });
        } catch (err) {
          resolve({
            error: 'Parse error',
            details: err.message,
          });
        }
      });
    });

    req.on('error', (error) => {
      resolve({
        error: 'Request failed',
        details: error.message,
      });
    });

    req.on('timeout', () => {
      req.destroy();
      resolve({
        error: 'Timeout',
        details: '10 second timeout exceeded',
      });
    });

    req.end();
  });
}

async function investigateRevenueCAT() {
  const userId = 'NkQa8IaOTlXgqTQGaukysv2q0jk2';
  
  console.log(`\n=== QUERYING REVENUECAT DIRECTLY ===`);
  console.log(`User ID: ${userId}\n`);
  console.log('Querying RevenueCat API for subscriber data...\n');

  const result = await queryRevenueCAT(userId);

  if (!result.found && result.statusCode === 404) {
    console.log('❌ USER NOT FOUND IN REVENUECAT');
    console.log('\nThis means:');
    console.log('- The app never called Purchases.logIn(userId) with this Firebase UID');
    console.log('- OR the app used a different ID than the Firebase UID');
    console.log('- OR the purchase was attempted before login\n');
  } else if (result.error) {
    console.log(`⚠️  ERROR: ${result.error}`);
    console.log(`Details: ${result.details}`);
  } else if (result.statusCode && result.statusCode !== 200) {
    console.log(`⚠️  RevenueCat API Error: ${result.statusCode}`);
    console.log(`Response: ${result.error}`);
  } else if (result.found) {
    console.log('✓ FOUND IN REVENUECAT\n');
    const customer = result.customerData.subscriber;
    
    console.log('=== CUSTOMER DATA ===');
    console.log(`App User ID: ${customer.app_user_id || 'NOT SET'}`);
    console.log(`Original App User ID: ${customer.original_app_user_id || 'N/A'}`);
    console.log(`First Seen: ${customer.first_seen || 'N/A'}`);
    console.log(`Management URL: ${customer.management_url || 'N/A'}`);
    
    console.log('\n=== SUBSCRIPTIONS ===');
    const subs = customer.subscriptions || {};
    if (Object.keys(subs).length === 0) {
      console.log('❌ NO SUBSCRIPTIONS');
    } else {
      Object.entries(subs).forEach(([key, sub]) => {
        console.log(`  Product: ${key}`);
        console.log(`    Expires: ${sub.expires_date || 'N/A'}`);
        console.log(`    Auto-Renew: ${sub.auto_resume_date ? 'YES' : 'NO'}`);
        console.log(`    Refunded: ${sub.refunded_at ? 'YES' : 'NO'}`);
      });
    }
    
    console.log('\n=== ENTITLEMENTS ===');
    const entitlements = customer.entitlements || {};
    if (Object.keys(entitlements).length === 0) {
      console.log('❌ NO ACTIVE ENTITLEMENTS');
    } else {
      Object.entries(entitlements).forEach(([key, ent]) => {
        console.log(`  ${key}: expires ${ent.expires_date}`);
      });
    }
    
    console.log('\n=== TRANSACTIONS ===');
    const txns = customer.non_subscriptions || {};
    if (Object.keys(txns).length === 0) {
      console.log('No non-subscription transactions');
    } else {
      Object.entries(txns).forEach(([key, txnArray]) => {
        console.log(`  ${key}: ${txnArray.length} transactions`);
        txnArray.forEach(t => {
          console.log(`    - Purchased: ${t.purchase_date}, Refunded: ${t.refunded_at || 'NO'}`);
        });
      });
    }
  }

  console.log('\n=== INTERPRETATION ===');
  if (!result.found && result.statusCode === 404) {
    console.log('ROOT CAUSE: Webhook cannot fire because RevenueCat has NO RECORD');
    console.log('of this user with the given app_user_id.\n');
    console.log('HYPOTHESIS: App did not call Purchases.logIn() correctly\n');
    console.log('NEXT STEPS:');
    console.log('1. Check if user verified their email/Firebase auth worked');
    console.log('2. Check if Android purchase flow calls Purchases.logIn()');
    console.log('3. Check app logs to see if auth provider is working');
  } else if (result.found) {
    console.log('User exists in RevenueCat, so webhook SHOULD have fired.');
    console.log('ROOT CAUSE: Webhook delivery failure or configuration issue.\n');
    console.log('NEXT STEPS:');
    console.log('1. Check RevenueCat webhook delivery logs in their dashboard');
    console.log('2. Verify webhook endpoint URL is correct in RevenueCat settings');
    console.log('3. Check Firebase Functions logs for webhook handler errors');
  }
}

investigateRevenueCAT().catch(err => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
