#!/usr/bin/env node

/**
 * Content Generator Script
 * 
 * Takes simple text input and converts to proper JSON schema for Firestore
 * 
 * Usage:
 *   node generate-content.js stories.txt  (generates stories.json)
 *   node generate-content.js polls.txt    (generates polls.json)
 */

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);

if (!args[0]) {
  console.error('Usage: node generate-content.js <input-file>');
  console.error('Example: node generate-content.js story.txt');
  process.exit(1);
}

const inputFile = args[0];

if (!fs.existsSync(inputFile)) {
  console.error(`File not found: ${inputFile}`);
  process.exit(1);
}

const content = fs.readFileSync(inputFile, 'utf-8');

// Detect if it's a story or poll
if (inputFile.toLowerCase().includes('story')) {
  generateStories(content);
} else if (inputFile.toLowerCase().includes('poll')) {
  generatePolls(content);
} else {
  console.error('Filename must contain "story" or "poll"');
  process.exit(1);
}

// ============================================================================
// STORIES GENERATOR
// ============================================================================

function generateStories(content) {
  const stories = [];
  const storyBlocks = content.split(/\n\n===STORY===\n\n/).filter(s => s.trim());

  storyBlocks.forEach((block, index) => {
    const story = parseStory(block, index + 1);
    if (story) stories.push(story);
  });

  const output = {
    version: 1,
    stories: stories
  };

  const outputFile = inputFile.replace(/\.[^.]+$/, '') + '.json';
  fs.writeFileSync(outputFile, JSON.stringify(output, null, 2));
  
  console.log(`✅ Generated ${outputFile}`);
  console.log(`   ${stories.length} stories created`);
  console.log('\nNext: Upload to Firestore at /cms/stories/current');
}

function parseStory(text, weekNum) {
  const lines = text.split('\n').map(l => l.trim()).filter(l => l);
  
  const story = {
    storyId: `story_week_${String(weekNum).padStart(2, '0')}`,
    weekNumber: weekNum,
    publishDate: new Date().toISOString().split('T')[0],
    audiences: ['single_never_married', 'divorced_widowed', 'married'],
    tags: ['relationship', 'wisdom'],
    title: '',
    subtitle: '',
    readingTimeMins: 4,
    contentBlocks: [],
    keyLessons: [],
    pollId: `poll_week_${String(weekNum).padStart(2, '0')}`,
    recommendedProductIds: []
  };

  let i = 0;
  
  // Title
  if (lines[0]?.startsWith('Title:')) {
    story.title = lines[0].replace('Title:', '').trim();
    i++;
  }

  // Subtitle
  if (lines[i]?.startsWith('Subtitle:')) {
    story.subtitle = lines[i].replace('Subtitle:', '').trim();
    i++;
  }

  // Category (optional)
  if (lines[i]?.startsWith('Category:')) {
    // Skip, we have default
    i++;
  }

  // Story content - collect all paragraphs until we hit Lesson:
  let storyContent = '';
  while (i < lines.length && !lines[i].startsWith('Lesson:')) {
    storyContent += (storyContent ? '\n\n' : '') + lines[i];
    i++;
  }
  
  // Add full story as single text block
  if (storyContent) {
    story.contentBlocks.push({
      type: 'text',
      content: storyContent.trim()
    });
  }

  // Lessons
  while (i < lines.length && lines[i]?.startsWith('Lesson:')) {
    story.keyLessons.push(lines[i].replace('Lesson:', '').trim());
    i++;
  }

  return story;
}

// ============================================================================
// POLLS GENERATOR
// ============================================================================

function generatePolls(content) {
  const polls = [];
  const pollBlocks = content.split(/\n\n===POLL===\n\n/).filter(p => p.trim());

  pollBlocks.forEach((block, index) => {
    const poll = parsePoll(block, index + 1);
    if (poll) polls.push(poll);
  });

  const output = {
    version: 1,
    polls: polls
  };

  const outputFile = inputFile.replace(/\.[^.]+$/, '') + '.json';
  fs.writeFileSync(outputFile, JSON.stringify(output, null, 2));
  
  console.log(`✅ Generated ${outputFile}`);
  console.log(`   ${polls.length} polls created`);
  console.log('\nNext: Upload to Firestore at /cms/polls/current');
}

function parsePoll(text, weekNum) {
  const lines = text.split('\n').map(l => l.trim()).filter(l => l);

  const poll = {
    pollId: `poll_week_${String(weekNum).padStart(2, '0')}`,
    storyId: `story_week_${String(weekNum).padStart(2, '0')}`,
    weekNumber: weekNum,
    question: '',
    options: [],
    defaultInsightCopy: 'Thanks for your response!',
    defaultRecommendedProductIds: []
  };

  let i = 0;

  // Question
  if (lines[0]?.startsWith('Question:')) {
    poll.question = lines[0].replace('Question:', '').trim();
    i++;
  }

  // Options (Option A: | Option B: format)
  while (i < lines.length && lines[i]?.match(/^Option\s+[A-Z]:/)) {
    const letter = lines[i].match(/^Option\s+([A-Z]):/)[1];
    const text = lines[i].replace(/^Option\s+[A-Z]:/, '').trim();
    
    poll.options.push({
      id: letter,
      text: text,
      inferredTags: [],
      insightCopy: `You selected: ${text}`,
      recommendedProductIds: [],
      votes: 0
    });
    i++;
  }

  return poll;
}
