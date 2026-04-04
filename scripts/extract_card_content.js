#!/usr/bin/env node

/**
 * Extract teaching card content for voice generation
 */

const fs = require('fs');
const path = require('path');

const journeyPath = path.join(__dirname, '../assets/config/journeys/married_journey_03_restoring_friendship.json');
const journey = JSON.parse(fs.readFileSync(journeyPath, 'utf8'));

const card = journey.activities[0].cards[0];

console.log('\n════════════════════════════════════════════════════════════\n');
console.log('📖 CARD DETAILS:\n');
console.log(`Card ID: ${card.cardId}`);
console.log(`Card Type: ${card.cardType}`);
console.log(`Title: "${card.title}"`);
console.log(`Activity: "${journey.activities[0].title}"`);
console.log(`Journey: "${journey.title}"\n`);

console.log('════════════════════════════════════════════════════════════\n');
console.log('📝 CARD TEXT (Ready to copy for TTS):\n');
console.log(card.text);
console.log('\n════════════════════════════════════════════════════════════\n');

console.log('💡 HOW TO USE THIS:\n');
console.log('1. Copy all the text above (from "**It rarely happens**" to "**...we are not friends anymore.**")');
console.log('2. Go to: https://tts.readspeak.com/');
console.log('3. Paste into the text box');
console.log('4. Select a warm, engaging voice');
console.log('5. Click "Generate"');
console.log('6. Download the MP3\n');

console.log('════════════════════════════════════════════════════════════\n');

// Also save to a text file for easy copy-paste
const outputPath = path.join(__dirname, '../teaching_card_text.txt');
fs.writeFileSync(outputPath, card.text, 'utf8');
console.log(`✅ Text also saved to: teaching_card_text.txt\n`);
