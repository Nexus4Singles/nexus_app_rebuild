const admin = require('firebase-admin');
const s = require('./serviceAccount.json');
admin.initializeApp({ credential: admin.credential.cert(s) });
const db = admin.firestore();
const { Timestamp } = admin.firestore;

(async () => {
  const todayMidnight = Timestamp.fromDate(new Date(new Date().setHours(0, 0, 0, 0)));
  console.log('Today midnight:', todayMidnight.toDate().toISOString());

  const coachIds = ['mock_coach_adaeze', 'mock_coach_seun', 'mock_coach_chisom'];
  for (const coachId of coachIds) {
    console.log(`\n--- Testing ${coachId} ---`);
    try {
      const snap = await db.collection('coaches').doc(coachId).collection('slots')
        .where('date', '>=', todayMidnight)
        .where('isBooked', '==', false)
        .orderBy('date')
        .orderBy('startTime')
        .limit(3)
        .get();
      console.log(`Query OK. Slots found: ${snap.size}`);
      snap.forEach(d => {
        const data = d.data();
        console.log(` - ${data.startTime} on ${data.date.toDate().toDateString()}, isBooked=${data.isBooked}`);
      });
    } catch (e) {
      console.error(`QUERY FAILED for ${coachId}:`, e.message);
    }

    // Also check raw slot count in subcollection
    try {
      const rawSnap = await db.collection('coaches').doc(coachId).collection('slots').limit(3).get();
      console.log(`Raw slot count (no filters, limit 3): ${rawSnap.size}`);
      rawSnap.forEach(d => {
        const data = d.data();
        console.log(` raw: startTime=${data.startTime}, date=${data.date?.toDate?.()?.toDateString?.()}, isBooked=${data.isBooked}`);
      });
    } catch (e) {
      console.error('Raw query failed:', e.message);
    }
  }
  process.exit(0);
})().catch(e => { console.error('Fatal:', e); process.exit(1); });
