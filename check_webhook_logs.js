#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexus-visibility-app'
});

const db = admin.firestore();

async function investigateGlobalLogs() {
  try {
    console.log('\n🔍 CHECKING GLOBAL FLUTTERWAVE COLLECTIONS\n');

    // Check if there's a global flutterwave_webhooks collection
    const webhooksSnapshot = await db
      .collection('flutterwave_webhooks')
      .orderBy('createdAt', 'desc')
      .limit(20)
      .get();

    console.log('📨 GLOBAL FLUTTERWAVE WEBHOOKS:\n');
    if (webhooksSnapshot.empty) {
      console.log('   ❌ No webhook records found (collection empty or doesn\'t exist)');
    } else {
      console.log('   ✅ Found ' + webhooksSnapshot.size + ' webhook record(s)\n');
      webhooksSnapshot.forEach(doc => {
        const data = doc.data();
        console.log('   Webhook ID: ' + doc.id);
        console.log('   • Status: ' + (data.status || 'N/A'));
        console.log('   • User ID: ' + (data.userId || 'N/A'));
        console.log('   • Transaction ID: ' + (data.transactionId || 'N/A'));
        console.log('   • Email: ' + (data.email || 'N/A'));
        console.log('   • Created: ' + (data.createdAt?.toDate?.() || data.createdAt));
        console.log('   • Error: ' + (data.error || 'N/A'));
        console.log('');
      });
    }

    // Check for failed webhooks
    const failedSnapshot = await db
      .collection('flutterwave_failed_webhooks')
      .orderBy('receivedAt', 'desc')
      .limit(10)
      .get();

    console.log('❌ FAILED WEBHOOKS:\n');
    if (failedSnapshot.empty) {
      console.log('   ✅ No failed webhooks (good!)');
    } else {
      console.log('   Found ' + failedSnapshot.size + ' failed webhook(s):\n');
      failedSnapshot.forEach(doc => {
        const data = doc.data();
        console.log('   • ' + doc.id);
        console.log('     Error: ' + (data.error || 'N/A'));
        console.log('     Received: ' + (data.receivedAt?.toDate?.() || data.receivedAt));
      });
    }

    console.log('\n📊 SUMMARY:\n');
    console.log('   If both collections are empty:');
    console.log('   → The Flutterwave webhook endpoint is NOT being called');
    console.log('   → Check: Is the webhook URL configured in Flutterwave dashboard?');
    console.log('   → Check: Is the Firebase Cloud Function deployed and accessible?');
    console.log('');

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

investigateGlobalLogs();
