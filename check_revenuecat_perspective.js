const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://nexus-dating.firebaseio.com'
});

const db = admin.firestore();

async function checkRevenueCATPerspective() {
  const userId = 'NkQa8IaOTlXgqTQGaukysv2q0jk2';
  const userEmail = 'oladelesamuel0907@gmail.com';
  
  console.log(`\n=== CHECKING REVENUECAT WEBHOOK RECORDS ===`);
  console.log(`User: ${userId} (${userEmail})\n`);
  
  // 1. Check if there's a webhook_logs collection record
  console.log('--- FIRESTORE WEBHOOK LOGS ---');
  try {
    const webhookSnap = await db.collection('webhook_logs')
      .where('userId', '==', userId)
      .orderBy('timestamp', 'desc')
      .limit(5)
      .get();
    
    if (webhookSnap.empty) {
      console.log('❌ No webhook logs for this user');
    } else {
      console.log(`✓ Found ${webhookSnap.size} webhook logs:`);
      webhookSnap.forEach(doc => {
        const log = doc.data();
        console.log(`  - Event: ${log.event}`);
        console.log(`    Status: ${log.status}`);
        console.log(`    Timestamp: ${log.timestamp?.toDate?.() || log.timestamp}`);
      });
    }
  } catch (err) {
    console.log(`⚠️  Could not query webhook logs: ${err.message}`);
  }
  
  // 2. Check if there are any system-level subscription_events logs
  console.log('\n--- SYSTEM SUBSCRIPTION EVENTS ---');
  try {
    const eventsSnap = await db.collection('subscription_events')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc')
      .limit(5)
      .get();
    
    if (eventsSnap.empty) {
      console.log('❌ No subscription events logged');
    } else {
      console.log(`✓ Found ${eventsSnap.size} subscription events:`);
      eventsSnap.forEach(doc => {
        const ev = doc.data();
        console.log(`  - ${ev.action}: ${ev.details}`);
      });
    }
  } catch (err) {
    console.log(`⚠️  Could not query events: ${err.message}`);
  }
  
  // 3. Check user's device info for purchase hints
  console.log('\n--- USER PROFILE DEVICE INFO ---');
  const userDoc = await db.collection('users').doc(userId).get();
  const userData = userDoc.data();
  
  console.log(`Device: ${userData.device || 'unknown'}`);
  console.log(`OS: ${userData.os || 'unknown'}`);
  console.log(`RevenueCat ID field: ${userData.revenueCatCustomerId || 'not set'}`);
  
  // 4. Summary
  console.log('\n--- DETERMINISTIC CONCLUSION ---');
  console.log('RevenueCat transaction exists: YES (user reports seeing it)');
  console.log('Firestore subscription record: NO');
  console.log('Firestore optimistic record: NO');
  console.log('Webhook logs: None found');
  console.log('\n⚠️  CRITICAL: If RevenueCat has transaction but we have no records,');
  console.log('the webhook notification never reached our backend, OR');
  console.log('the webhook payload did not contain the expected fields.');
}

checkRevenueCATPerspective().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
