#!/usr/bin/env node

// Usage:
// 1) Place your Firebase service account key JSON beside this file as serviceAccount.json
// 2) Run: node seed_firestore.js
// 3) Delete the key and this script after seeding

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const keyPath = path.join(__dirname, 'serviceAccount.json');
if (!fs.existsSync(keyPath)) {
  console.error('❌ Missing serviceAccount.json next to seed_firestore.js');
  process.exit(1);
}

const serviceAccount = require(keyPath);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// Data payloads (matches FIRESTORE_INITIAL_DATA.md)
const versions = {
  stories: { version: 1, releaseNotes: 'Initial content' },
  polls: { version: 1, releaseNotes: 'Initial polls' },
};

const stories = {
  version: 1,
  stories: [
    {
      storyId: 'story_week_01',
      weekNumber: 1,
      publishDate: '2026-01-26',
      audiences: ['single_never_married', 'divorced_widowed', 'married'],
      tags: ['relationship', 'wisdom'],
      title: 'Ade & Feyi: First Year Wisdom',
      subtitle: "Love survived the first test—here's what they learned",
      readingTimeMins: 4,
      contentBlocks: [
        {
          type: 'text',
          content:
            'Ade and Feyi had been together since university, but their first year of marriage felt like starting over. They had to learn each other all over again, and that was terrifying—until it became beautiful.\n\nThey thought marriage would be smooth because they already knew each other. What they did not expect was how differently they handled stress. Ade withdrew when anxious. Feyi pushed for immediate resolution. Their first real conflict caught them completely unprepared—no script, no parents to call, just them, alone in their apartment, frustrated.\n\nOne night after yet another misunderstanding, Feyi said something that shifted everything: "I am not trying to win. I am trying to understand you." Those words cracked something open in Ade. He realized he had been defending instead of connecting. They spent that night—not arguing—but talking. Real talking. About fears, about dreams, about what they needed from each other that they had never said out loud.\n\nThey made a commitment to three things: When tension rises, they pause instead of pushing. They ask questions before making assumptions. They repair quickly—pride costs more than humility. And it works. Not perfectly, but genuinely.',
        },
      ],
      keyLessons: [
        'Your first big fight will reveal your patterns—notice them without shame',
        'Pausing is not weakness; it is wisdom',
        'The couple that repairs together, stays together',
        'Love is not what you feel in the beginning; it is what you build after the beginning',
      ],
      pollId: 'poll_week_01',
      recommendedProductIds: [],
    },
  ],
};

const polls = {
  version: 1,
  polls: [
    {
      pollId: 'poll_week_01',
      storyId: 'story_week_01',
      weekNumber: 1,
      question: 'When conflict starts, what do you usually do first?',
      options: [
        {
          id: 'A',
          text: 'I withdraw to avoid escalation',
          inferredTags: [],
          insightCopy: 'You selected: I withdraw to avoid escalation',
          recommendedProductIds: [],
          votes: 0,
        },
        {
          id: 'B',
          text: 'I push for clarity immediately',
          inferredTags: [],
          insightCopy: 'You selected: I push for clarity immediately',
          recommendedProductIds: [],
          votes: 0,
        },
        {
          id: 'C',
          text: 'I use humor / change topic',
          inferredTags: [],
          insightCopy: 'You selected: I use humor / change topic',
          recommendedProductIds: [],
          votes: 0,
        },
        {
          id: 'D',
          text: 'It depends on the person',
          inferredTags: [],
          insightCopy: 'You selected: It depends on the person',
          recommendedProductIds: [],
          votes: 0,
        },
      ],
      defaultInsightCopy: 'Thanks for your response!',
      defaultRecommendedProductIds: [],
    },
  ],
};

(async () => {
  try {
    await db.doc('cms/versions').set(versions);
    await db.doc('cms/stories').set(stories);
    await db.doc('cms/polls').set(polls);
    console.log('✅ Seed complete');
    process.exit(0);
  } catch (err) {
    console.error('❌ Seed failed:', err);
    process.exit(1);
  }
})();
