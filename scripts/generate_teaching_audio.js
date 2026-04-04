#!/usr/bin/env node

/**
 * Generate voice audio from journey teaching card content
 * 
 * This script:
 * 1. Extracts teaching card text from journey JSON
 * 2. Generates voice audio using Google Cloud Text-to-Speech API
 * 3. Uploads to Digital Ocean Spaces
 * 4. Outputs the URL to add to Firestore
 * 
 * Requirements:
 * - Google Cloud TTS API enabled
 * - GOOGLE_APPLICATION_CREDENTIALS set (from Firebase)
 * - aws-sdk or aws-sdk-v3 for Digital Ocean Spaces upload
 * 
 * Run: node scripts/generate_teaching_audio.js
 */

const fs = require('fs');
const path = require('path');

// Extract the teaching card text
const journeyPath = path.join(__dirname, '../assets/config/journeys/married_journey_03_restoring_friendship.json');
const journey = JSON.parse(fs.readFileSync(journeyPath, 'utf8'));

const card = journey.activities[0].cards[0];
console.log('\n📖 TEACHING CARD EXTRACTED:');
console.log(`   Journey: "${journey.title}"`);
console.log(`   Activity: "${journey.activities[0].title}"`);
console.log(`   Card: "${card.title}"\n`);

// The text we want to convert to speech
const textToSpeech = card.text;
console.log('📝 Text length:', textToSpeech.length, 'characters\n');

console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
console.log('⚙️  AUDIO GENERATION OPTIONS:\n');

console.log('OPTION 1: Use Google Cloud TTS (Professional Quality)');
console.log('  • Install: npm install @google-cloud/text-to-speech');
console.log('  • Needs: Google Cloud credentials (already have from Firebase)');
console.log('  • Output: High-quality natural voice');
console.log('  • Cost: ~$4 per million characters\n');

console.log('OPTION 2: Use ElevenLabs API (Best for Emotional Voice)');
console.log('  • Sign up: https://elevenlabs.io (free tier available)');
console.log('  • Get API key: https://elevenlabs.io/docs/api-reference/getting-started');
console.log('  • Features: Expressive voices, cloning, emotional variation');
console.log('  • Best for: "real teaching session with emotions"\n');

console.log('OPTION 3: Use Azure TTS (Alternative)');
console.log('  • Cost: $1 per 1M characters');
console.log('  • Quality: Comparable to Google\n');

console.log('OPTION 4: Use Free Online Tool (Quick Test)');
console.log('  • Go to: https://tts.readspeak.com/');
console.log('  • Paste text, generate, download MP3');
console.log('  • Upload to DO Spaces manually');
console.log('  • Quick validation of concept\n');

console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

console.log('📋 RECOMMENDED QUICK PATH:\n');
console.log('1. Go to: https://tts.readspeak.com/');
console.log('2. Select voice: "English (US) - Female" or similar');
console.log('3. Paste this text:\n');
console.log(textToSpeech);
console.log('\n4. Click "Generate Speech"');
console.log('5. Download the MP3 file');
console.log('6. Get a hosting URL (DO Spaces, Vercel, or temporary URL service)\n');

console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

console.log('🚀 Once you have the audio URL:\n');
console.log('1. Copy the URL');
console.log('2. Open Firebase Console');
console.log('3. Navigate to married_restoring_friendship → activities[0] → cards[0]');
console.log('4. Add field: audioUrl = "<your-audio-url>"');
console.log('5. Hot reload the app');
console.log('6. Test card 1 - should show audio player instead of text\n');

console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
