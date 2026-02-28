const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

/**
 * SCHEDULED CLOUD FUNCTION: Reset Daily Limits for Free Users (V2)
 */
exports.resetDailyLimits = onSchedule({
  schedule: '0 0 * * *',
  timeZone: 'UTC',
  memory: '256MiB',
}, async (event) => {
  try {
    const db = admin.firestore();
    const now = new Date();
    
    // We scan users who have a hit on the daily limit
    const usersSnapshot = await db.collection('users')
      .where('dating.dailyLimitFirstHit', '!=', null)
      .get();
    
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const dailyLimitFirstHit = userDoc.get('dating.dailyLimitFirstHit');
      
      const limitHitDate = dailyLimitFirstHit.toDate();
      const hoursSince = (now - limitHitDate) / (1000 * 60 * 60);

      if (hoursSince >= 24) {
        await db.collection('users').doc(userId).update({
          'dating.dailyLimitFirstHit': admin.firestore.FieldValue.delete(),
          'dating.shownProfileIds': admin.firestore.FieldValue.delete(),
          'dating.lastResetAt': admin.firestore.Timestamp.now(),
        });
        console.log(`✅ [resetDailyLimits] Reset user ${userId}`);
      }
    }
  } catch (error) {
    console.error('💥 [resetDailyLimits] CRITICAL ERROR:', error);
  }
});
