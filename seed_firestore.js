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
      tags: ['Marriage', 'Communication', 'Conflict'],
      title: 'Ade & Feyi: First Year Wisdom',
      subtitle: "Love survived the first test; here's what they learned",
      readingTimeMins: 10,
      contentBlocks: [
        {
          type: 'text',
          content:
            'Ade and Feyi met in university. They had seen each other at their worst: bad grades, broke months, long nights, big dreams. So when they got married, they believed they already had the hard part sorted.\n\nThen marriage started.\n\nNot the wedding. Not the pictures. The ordinary days.\n\nTheir first year did not feel like a continuation. It felt like a reset.\n\nThey moved into a small apartment that still smelled like fresh paint. The first weeks were sweet: late-night noodles, inside jokes, feet touching under the blanket. They would laugh and say, "We are finally here."\n\nBut life does not clap for you because you are in love. Life just keeps coming.\n\nAde\'s job got tense. New targets. Longer hours. A manager who never smiled. When Ade felt pressure, he became quiet. Not angry quiet, just... gone. Like he was saving his words for later.\n\nFeyi was the opposite. When she felt pressure, she needed answers. She wanted to talk, settle it, fix it now, before it grew teeth.\n\nAt first, it looked small.\n\nAde would come home, greet her, and head straight to the bathroom, phone in hand, shower running too long.\nFeyi would pretend she did not notice, but she noticed.\n\nOne evening, she asked, "Are you okay?"\nAde said, "I am fine."\nBut his eyes did not match his mouth.\n\nFeyi followed him into the kitchen. "You have been fine for three days."\n\nAde kept rinsing a cup that was already clean. "I said I am fine."\n\nThat is how their first real fight began, not with shouting, but with a wall.\n\nIt did not help that people kept calling.\n\n"How is marriage?"\n"Hope he is treating you well."\n"Hope she is respecting you."\n\nAdvice came like rain. Everybody had something to say, but nobody was in the apartment with them at 11:43 p.m., when the silence felt heavy.\n\nThen the misunderstanding happened.\n\nIt was a simple thing. A message popped up on Ade\'s phone while he was changing clothes. Feyi was not snooping. The screen just lit up.\n\n"Did you tell her?"\n\nThat was all she saw.\n\nHer stomach dropped. Not because she had proof of anything, but because fear is fast. Fear does not wait for full sentences.\n\nAde noticed her face change. "What is wrong?"\n\nFeyi swallowed. "Who is that?"\n\nAde looked at his phone and froze for half a second. Just half. But half is enough to start a fire.\n\n"It is nothing," he said, too quickly.\n\nFeyi\'s voice got tight. "Ade. Who is that?"\n\nHe sighed, already tired. "Can we not do this tonight?"\n\nThat sentence, "Can we not do this tonight?" hit her like a slap.\n\nTo Feyi, it sounded like: I have something to hide.\nTo Ade, it meant: I do not have energy for another fight.\n\nShe stepped back, arms folded. "So you will not even explain?"\n\nAde\'s shoulders sank. He walked to the edge of the bed and sat down like someone carrying a bag nobody could see.\n\n"I cannot," he said.\n\nFeyi stared. "You cannot... or you will not?"\n\nAde did not answer.\n\nAnd there it was: the apartment, the two of them, alone. No script. No parents to call. No friend who could walk in and save the moment. Just the truth they were avoiding.\n\nFeyi spent that night turning in bed, listening to the ceiling fan, asking herself questions she hated. Ade spent that night staring at the wall, wishing he could pause life the way you pause a song.\n\nThe next day, they did not fight. They did something worse.\n\nThey acted normal.\n\nGood morning.\nFood on the table.\nPolite smiles.\n\nBut their bodies were present and their hearts were not.\n\nBy evening, the air between them felt thick. Even the TV sounded far away.\n\nFeyi finally broke.\n\nShe sat on the couch, not facing him. "I do not want to be that wife who imagines things. But you are making it hard."\n\nAde rubbed his forehead. "Feyi..."\n\nShe turned, eyes shiny but steady. "I am not trying to win. I am trying to understand you."\n\nThe room went quiet in a different way.\n\nAde blinked. His mouth opened, then closed, like something in him was deciding whether to run or stay.\n\nThen he did something Feyi did not expect.\n\nHe told the truth.\n\n"That message," he said softly, "was from my friend Kunle. He knows I have been struggling at work. He asked if I told you yet."\n\nFeyi did not speak.\n\nAde continued, voice low. "I did not tell you because I was ashamed. My performance has not been great. They warned me. I have been scared... and I did not want you to look at me like I failed."\n\nFeyi\'s chest tightened. So that was it. Not a secret life. Just fear.\n\nShe moved closer. "Ade... why would I look at you like that?"\n\nHe laughed once, but it was not happy. "Because I keep hearing this voice in my head saying a husband must always be strong. Always have it together. And when I do not... I shut down."\n\nFeyi\'s eyes filled properly now. "And when you shut down, I panic. Because I do not know where you go. I am here, but it feels like I am alone."\n\nThey sat there for a long time.\n\nNo big speeches. No perfect lines.\n\nJust two people finally saying the things they kept swallowing.\n\nAde admitted he withdrew when he felt small.\nFeyi admitted she pushed when she felt unsafe.\nBoth of them admitted they were tired of fighting shadows.\n\nThat night, they did not "solve marriage."\n\nThey chose each other again, properly.\n\nThey made three simple agreements.\n\nFirst: When tension rises, they pause. Not to punish. Not to run. Just to breathe.\nA short break. A glass of water. A walk to the window. Then they return.\n\nSecond: They ask questions before making conclusions.\nNot "Who is that?" like an accusation.\nBut "I saw a message and it scared me. Can you help me understand?"\n\nThird: They repair quickly.\nIf one of them messes up, they own it early.\nBecause pride does not protect love. It drains it.\n\nIt did not become perfect.\n\nAde still went quiet sometimes.\nFeyi still wanted answers fast sometimes.\n\nBut now, when the old pattern tried to return, they could name it.\n\n"Hey... I am shutting down."\n"Hey... I am spiraling."\n\nAnd naming it made it smaller.\n\nWeeks later, Feyi would joke, "So you are going to wash the same cup for ten minutes again?"\nAde would laugh and say, "Okay, okay. I am here."\n\nAnd in that small moment, simple, ordinary, real, you could see the truth:\n\nLove is not only the beginning.\nLove is the work you do after the beginning, when nobody is clapping and it is just the two of you in the room.',
        },
      ],
      keyLessons: [
        'Your first big fight will reveal your patterns; notice them without shame',
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
