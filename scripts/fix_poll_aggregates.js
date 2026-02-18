/**
 * POLL AGGREGATE FIX SCRIPT
 * 
 * Recalculates and fixes corrupted poll aggregates.
 * 
 * USAGE:
 * node scripts/fix_poll_aggregates.js poll_week_01
 * or
 * node scripts/fix_poll_aggregates.js --all
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase
const serviceAccount = require(path.join(__dirname, '../serviceAccount.json'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function recalculatePollAggregate(pollId) {
  try {
    console.log(`\n📊 Recalculating aggregate for ${pollId}...`);

    // Get all votes for this poll
    const votesSnapshot = await db
      .collection('pollVotes')
      .doc(pollId)
      .collection('votes')
      .get();

    console.log(`   Found ${votesSnapshot.size} votes`);

    // Calculate optionCounts from individual votes
    const optionCounts = {};
    votesSnapshot.forEach(doc => {
      const vote = doc.data();
      const optionId = vote.selectedOptionId;
      optionCounts[optionId] = (optionCounts[optionId] || 0) + 1;
    });

    const totalVotes = votesSnapshot.size;

    // Show before/after
    const beforeSnapshot = await db.collection('pollAggregates').doc(pollId).get();
    if (beforeSnapshot.exists) {
      const before = beforeSnapshot.data();
      console.log(`   BEFORE: totalVotes=${before.totalVotes}, optionCounts=${JSON.stringify(before.optionCounts)}`);
    }

    // Update the aggregate document
    await db.collection('pollAggregates').doc(pollId).update({
      optionCounts: optionCounts,
      totalVotes: totalVotes,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`   AFTER:  totalVotes=${totalVotes}, optionCounts=${JSON.stringify(optionCounts)}`);
    console.log(`   ✅ Successfully fixed ${pollId}`);

    return { success: true, pollId, totalVotes, optionCounts };
  } catch (error) {
    console.error(`   ❌ Error fixing ${pollId}:`, error.message);
    return { success: false, pollId, error: error.message };
  }
}

async function fixAllPolls() {
  try {
    console.log('\n🔧 Fetching all polls...');
    
    const pollsSnapshot = await db.collection('pollAggregates').get();
    console.log(`Found ${pollsSnapshot.size} polls to check\n`);

    const results = [];
    for (const doc of pollsSnapshot.docs) {
      const result = await recalculatePollAggregate(doc.id);
      results.push(result);
    }

    // Summary
    const successful = results.filter(r => r.success).length;
    console.log(`\n✨ SUMMARY: ${successful}/${results.length} polls fixed`);
    
    return results;
  } catch (error) {
    console.error('❌ Error fetching polls:', error.message);
    process.exit(1);
  }
}

// Main
const args = process.argv.slice(2);
if (args.length === 0) {
  console.log('USAGE: node scripts/fix_poll_aggregates.js poll_week_01');
  console.log('   or: node scripts/fix_poll_aggregates.js --all');
  process.exit(1);
}

const pollId = args[0];

if (pollId === '--all') {
  fixAllPolls().then(() => {
    console.log('\n✨ All done!');
    process.exit(0);
  });
} else {
  recalculatePollAggregate(pollId).then(() => {
    console.log('\n✨ Done!');
    process.exit(0);
  });
}
