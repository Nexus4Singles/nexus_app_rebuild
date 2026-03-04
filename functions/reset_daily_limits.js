const functions = require("firebase-functions");
const admin = require("firebase-admin");

/**
 * SCHEDULED CLOUD FUNCTION: Reset Daily Limits for Free Users (V1 API)
 * Runs every day at midnight UTC.
 * Clears dailyLimitFirstHit and shownProfileIds for users whose 24h has passed.
 */
exports.resetDailyLimits = functions.pubsub
  .schedule('0 0 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      const db = admin.firestore();
      const now = new Date();

      // Query only users with an active daily limit (efficient — avoids full scan)
      const usersSnapshot = await db.collection('users')
        .where('dating.dailyLimitFirstHit', '!=', null)
        .get();

      console.log(`📊 [resetDailyLimits] Scanning ${usersSnapshot.size} users with active limits`);

      let resetCount = 0;

      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const dailyLimitFirstHit = userDoc.get('dating.dailyLimitFirstHit');

        if (!dailyLimitFirstHit) continue;

        const limitHitDate = dailyLimitFirstHit.toDate
          ? dailyLimitFirstHit.toDate()
          : dailyLimitFirstHit;
        const hoursSince = (now - limitHitDate) / (1000 * 60 * 60);

        if (hoursSince >= 24) {
          await db.collection('users').doc(userId).update({
            'dating.dailyLimitFirstHit': admin.firestore.FieldValue.delete(),
            'dating.shownProfileIds': admin.firestore.FieldValue.delete(),
            'dating.lastResetAt': admin.firestore.Timestamp.now(),
          });
          resetCount++;
          console.log(`✅ [resetDailyLimits] Reset user ${userId} (${hoursSince.toFixed(1)}h passed)`);
        }
      }

      console.log(`🏁 [resetDailyLimits] Done. Reset ${resetCount}/${usersSnapshot.size} users.`);
    } catch (error) {
      console.error('💥 [resetDailyLimits] CRITICAL ERROR:', error);
    }
  });
