const admin = require('firebase-admin');
const s = require('./serviceAccount.json');
admin.initializeApp({ credential: admin.credential.cert(s) });
const db = admin.firestore();
const { Timestamp } = admin.firestore;

function futureDay(n) {
  const d = new Date();
  d.setDate(d.getDate() + n);
  d.setHours(0, 0, 0, 0);
  return Timestamp.fromDate(d);
}

const ALL_TYPES = ['Individual', 'Premarital', 'PostMarital', 'Parenting'];

const coaches = [
  {
    id: 'mock_coach_adaeze',
    data: {
      userId: 'mock_coach_adaeze',
      name: 'Dr. Adaeze Okonkwo',
      title: 'Licensed Marriage & Family Therapist',
      bio: 'With over 12 years of experience helping couples and individuals navigate relationship challenges, Dr. Adaeze brings warmth, wisdom, and evidence-based approaches to every session. She specialises in rebuilding trust, communication and intimacy.',
      profilePhotoUrl: 'https://randomuser.me/api/portraits/women/44.jpg',
      sessionTypes: ALL_TYPES,
      specializations: ['Communication', 'Trust Rebuilding', 'Pre-marital Prep', 'Grief & Loss'],
      sessionRates: { Individual: 25000, Premarital: 30000, PostMarital: 30000, Parenting: 28000 },
      currency: 'NGN',
      rating: 4.9,
      totalRatings: 47,
      totalSessions: 63,
      timezone: 'Africa/Lagos',
      isAvailable: true,
      approvedAt: Timestamp.now(),
      yearsOfExperience: 12,
      email: 'adaeze.okonkwo@nexuscounselling.com',
      linkedinProfile: null,
      instagramHandle: null,
      phoneNumber: null,
    }
  },
  {
    id: 'mock_coach_seun',
    data: {
      userId: 'mock_coach_seun',
      name: 'Pastor Seun Adeleke',
      title: 'Christian Marriage Counselor & Life Coach',
      bio: 'Pastor Seun combines faith-based principles with practical counselling strategies to help couples build Christ-centred marriages. He has worked with over 200 premarital couples and offers a nurturing, non-judgmental space for all sessions.',
      profilePhotoUrl: 'https://randomuser.me/api/portraits/men/32.jpg',
      sessionTypes: ['Premarital', 'PostMarital', 'Individual'],
      specializations: ['Faith-based Counselling', 'Conflict Resolution', 'Sexual Intimacy', 'Blended Families'],
      sessionRates: { Individual: 20000, Premarital: 25000, PostMarital: 25000, Parenting: 22000 },
      currency: 'NGN',
      rating: 4.7,
      totalRatings: 89,
      totalSessions: 110,
      timezone: 'Africa/Lagos',
      isAvailable: true,
      approvedAt: Timestamp.now(),
      yearsOfExperience: 9,
      email: 'seun.adeleke@nexuscounselling.com',
      linkedinProfile: null,
      instagramHandle: null,
      phoneNumber: null,
    }
  },
  {
    id: 'mock_coach_chisom',
    data: {
      userId: 'mock_coach_chisom',
      name: 'Chisom Nwafor MSc',
      title: 'Psychotherapist & Parenting Coach',
      bio: 'Chisom is a certified psychotherapist with specialist training in child psychology and family systems. She helps parents develop healthier communication patterns, manage conflict in front of children, and raise emotionally intelligent kids.',
      profilePhotoUrl: 'https://randomuser.me/api/portraits/women/68.jpg',
      sessionTypes: ['Parenting', 'Individual', 'PostMarital'],
      specializations: ['Parenting Strategies', 'Child Behaviour', 'Co-parenting', 'Anxiety & Stress'],
      sessionRates: { Individual: 18000, Premarital: 20000, PostMarital: 22000, Parenting: 20000 },
      currency: 'NGN',
      rating: 4.8,
      totalRatings: 34,
      totalSessions: 42,
      timezone: 'Africa/Lagos',
      isAvailable: true,
      approvedAt: Timestamp.now(),
      yearsOfExperience: 7,
      email: 'chisom.nwafor@nexuscounselling.com',
      linkedinProfile: null,
      instagramHandle: null,
      phoneNumber: null,
    }
  }
];

const slotTimes = [
  { startTime: '09:00', endTime: '10:00', durationMinutes: 60 },
  { startTime: '11:00', endTime: '12:00', durationMinutes: 60 },
  { startTime: '14:00', endTime: '15:00', durationMinutes: 60 },
  { startTime: '16:00', endTime: '17:00', durationMinutes: 60 },
];

async function deleteAllSlots(coachId) {
  const slotsRef = db.collection('coaches').doc(coachId).collection('slots');
  let deletedTotal = 0;
  // Firestore doesn't support bulk delete; read in pages of 400, delete in batches
  let snap = await slotsRef.limit(400).get();
  while (!snap.empty) {
    const delBatch = db.batch();
    snap.docs.forEach(d => delBatch.delete(d.ref));
    await delBatch.commit();
    deletedTotal += snap.size;
    snap = await slotsRef.limit(400).get();
  }
  if (deletedTotal > 0) console.log(`  Cleared ${deletedTotal} stale slots for ${coachId}`);
}

async function seed() {
  // Step 1: clear all existing slots so re-runs don't produce duplicates
  console.log('Clearing existing slots…');
  for (const coach of coaches) {
    await deleteAllSlots(coach.id);
  }

  // Step 2: seed coaches + fresh slots
  // Firestore batch limit is 500 ops; split into multiple batches
  let batch = db.batch();
  let opCount = 0;

  async function flushIfNeeded() {
    if (opCount >= 450) {
      await batch.commit();
      batch = db.batch();
      opCount = 0;
    }
  }

  for (const coach of coaches) {
    const coachRef = db.collection('coaches').doc(coach.id);
    batch.set(coachRef, coach.data, { merge: true });
    opCount++;

    for (let day = 1; day <= 14; day++) {
      // Vary slots per day: every day gets 2-4 slots
      const slotsForDay = slotTimes.filter((_, i) => (i + day) % 2 === 0 || day % 3 === 0);
      for (const slot of slotsForDay) {
        const slotRef = coachRef.collection('slots').doc();
        batch.set(slotRef, {
          coachId: coach.id,
          date: futureDay(day),
          startTime: slot.startTime,
          endTime: slot.endTime,
          durationMinutes: slot.durationMinutes,
          isBooked: false,
          bookingId: null,
          sessionTypes: coach.data.sessionTypes,
        });
        opCount++;
        await flushIfNeeded();
      }
    }
  }

  await batch.commit();
  console.log('Seeded 3 mock coaches with availability slots for the next 14 days.');
  process.exit(0);
}

seed().catch(e => { console.error('FAILED:', e.message); process.exit(1); });
