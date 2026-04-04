const admin = require('firebase-admin');
const s = require('./serviceAccount.json');
admin.initializeApp({ credential: admin.credential.cert(s) });
const db = admin.firestore();

const COACH_UID = 'yjXNtVfxyraQBmD2LEvvaiGWrJo1'; // nexus4singles@gmail.com (Ayodeji)

(async () => {
  // ── 1. Create (or overwrite) the coach document ──────────────────────────
  const coachRef = db.collection('coaches').doc(COACH_UID);
  await coachRef.set({
    userId: COACH_UID,
    name: 'Ayodeji (Test Coach)',
    bio: 'Licensed marriage and relationship counselor with 8 years of experience helping couples build godly, lasting relationships.',
    profilePhotoUrl: null,
    sessionTypes: ['Individual', 'Premarital', 'PostMarital', 'Parenting'],
    sessionRates: {
      Individual: 15000,
      Premarital: 20000,
      PostMarital: 20000,
      Parenting: 18000,
    },
    currency: 'NGN',
    timezone: 'Africa/Lagos',
    rating: 4.8,
    totalRatings: 12,
    totalSessions: 24,
    isActive: true,
    email: 'nexus4singles@gmail.com',
    specializations: ['Marriage Counseling', 'Conflict Resolution', 'Premarital Preparation'],
    createdAt: admin.firestore.Timestamp.now(),
  });
  console.log('✅ Coach document created:', coachRef.id);

  // ── 2. Seed 7 days of future slots ───────────────────────────────────────
  const slotsRef = coachRef.collection('slots');

  // Delete any existing slots for this coach first
  const existingSlots = await slotsRef.get();
  const deleteBatch = db.batch();
  existingSlots.forEach(d => deleteBatch.delete(d.ref));
  if (!existingSlots.empty) {
    await deleteBatch.commit();
    console.log(`🗑️  Deleted ${existingSlots.size} existing slots`);
  }

  const sessionTypes = ['Individual', 'Premarital', 'PostMarital', 'Parenting'];

  // Create 2 slots per day for the next 7 days
  const seedBatch = db.batch();
  let slotCount = 0;

  for (let dayOffset = 1; dayOffset <= 7; dayOffset++) {
    const date = new Date();
    date.setDate(date.getDate() + dayOffset);
    date.setHours(0, 0, 0, 0);
    const dateTimestamp = admin.firestore.Timestamp.fromDate(date);

    const timeSlots = [
      { start: '09:00', end: '10:00' },
      { start: '14:00', end: '15:00' },
    ];

    for (const t of timeSlots) {
      const slotRef = slotsRef.doc();
      seedBatch.set(slotRef, {
        coachId: COACH_UID,
        date: dateTimestamp,
        startTime: t.start,
        endTime: t.end,
        durationMinutes: 60,
        isBooked: false,
        bookingId: null,
        sessionTypes,
        createdAt: admin.firestore.Timestamp.now(),
      });
      slotCount++;
    }
  }

  await seedBatch.commit();
  console.log(`✅ Created ${slotCount} time slots over the next 7 days`);
  console.log('\n🎉 Done! Log into the app as nexus4singles@gmail.com to test the coach journey.');
  console.log('   → Coach Dashboard should now appear because userId matches the coaches document.');
})().catch(err => {
  console.error('❌ Error:', err.message);
  process.exit(1);
});
