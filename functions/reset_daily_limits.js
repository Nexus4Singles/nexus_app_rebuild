const functions = require("firebase-functions");
const admin = require("firebase-admin");

/**
 * SCHEDULED CLOUD FUNCTION: Reset Daily Limits for Free Users
 * 
 * Runs EVERY DAY at 00:00 UTC
 * Purpose: Clear dailyLimitFirstHit and shownProfileIds for free users whose 24h has passed
 * 
 * APPROACH (FAILSAFE):
 * 1. Query all users with active dailyLimitFirstHit
 * 2. Check if 24+ hours have passed
 * 3. ATOMICALLY delete both fields in transaction
 * 4. Log audit trail (for debugging if things go wrong)
 * 5. Send FCM notification ONLY if reset succeeded
 * 
 * SAFETY MECHANISMS:
 * - All deletions are transactional (all-or-nothing)
 * - Lazy reset still exists on client as backup
 * - Audit log tracks every execution
 * - Notifications only sent after confirmed reset
 */

exports.resetDailyLimits = functions.pubsub
  .schedule('0 0 * * *') // Every day at midnight UTC
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      console.log('🌙 [resetDailyLimits] Starting scheduled reset at', new Date().toISOString());
      
      const db = admin.firestore();
      const now = new Date();
      const resetStats = {
        processed: 0,
        reset: 0,
        failed: 0,
        notified: 0,
        errors: [],
      };

      // STEP 1: Query all users collection to find those with active limits
      // Note: We need to scan all users since dailyLimitFirstHit might exist for some
      const usersSnapshot = await db.collection('users').get();
      
      console.log(`📊 [resetDailyLimits] Scanning ${usersSnapshot.size} users for expired limits`);

      // STEP 2: Check each user and reset if needed
      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data();
        const dailyLimitFirstHit = userData?.['dating.dailyLimitFirstHit'];

        if (!dailyLimitFirstHit) {
          continue; // User has no active limit
        }

        resetStats.processed++;

        try {
          const limitHitDate = dailyLimitFirstHit.toDate ? dailyLimitFirstHit.toDate() : dailyLimitFirstHit;
          const hoursSince = (now - limitHitDate) / (1000 * 60 * 60);

          // Check if 24+ hours have passed
          if (hoursSince < 24) {
            console.log(`⏱️  [resetDailyLimits] User ${userId}: limit still active (${hoursSince.toFixed(1)}h)`);
            continue;
          }

          // STEP 3: Atomically delete both fields in transaction
          console.log(`🔄 [resetDailyLimits] Resetting limit for user ${userId} (${hoursSince.toFixed(1)}h passed)`);
          
          const success = await db.runTransaction(async (transaction) => {
            // Read current document to verify state
            const userRef = db.collection('users').doc(userId);
            const doc = await transaction.get(userRef);

            if (!doc.exists) {
              console.warn(`⚠️  [resetDailyLimits] User ${userId} no longer exists`);
              return false;
            }

            const currentLimit = doc.get('dating.dailyLimitFirstHit');
            if (!currentLimit) {
              console.log(`ℹ️  [resetDailyLimits] User ${userId} limit already cleared`);
              return false;
            }

            // Atomic update: delete both fields
            transaction.update(userRef, {
              'dating.dailyLimitFirstHit': admin.firestore.FieldValue.delete(),
              'dating.shownProfileIds': admin.firestore.FieldValue.delete(),
              'dating.lastResetAt': admin.firestore.Timestamp.now(), // For audit
            });

            return true;
          });

          if (success) {
            resetStats.reset++;
            console.log(`✅ [resetDailyLimits] Successfully reset user ${userId}`);

            // STEP 4: Log audit trail
            try {
              await db.collection('auditLog').add({
                type: 'DAILY_LIMIT_RESET',
                userId: userId,
                timestamp: admin.firestore.Timestamp.now(),
                hoursSinceLimit: hoursSince,
                status: 'SUCCESS',
              });
            } catch (auditError) {
              console.warn(`⚠️  [resetDailyLimits] Failed to log audit for ${userId}:`, auditError);
            }

            // STEP 5: Send FCM notification ONLY after confirmed reset
            try {
              // Get user's FCM token if available
              const fcmToken = userData?.fcmTokens?.[0]; // Most recent token
              
              if (fcmToken) {
                const message = {
                  notification: {
                    title: '✨ New Profiles Available!',
                    body: '10 fresh profiles waiting for you today',
                  },
                  webpush: {
                    notification: {
                      badge: '🎯',
                      icon: 'https://nexusapp.com/icon-192.png', // Replace with your icon URL
                    },
                  },
                  data: {
                    action: 'OPEN_DATING_SEARCH',
                    timestamp: new Date().toISOString(),
                  },
                };

                await admin.messaging().send({
                  ...message,
                  token: fcmToken,
                });

                resetStats.notified++;
                console.log(`📲 [resetDailyLimits] Notification sent to user ${userId}`);
              } else {
                console.log(`ℹ️  [resetDailyLimits] No FCM token for user ${userId}, skipping notification`);
              }
            } catch (notifError) {
              console.warn(`⚠️  [resetDailyLimits] Failed to send notification to ${userId}:`, notifError);
              // Don't count as failure - reset succeeded even if notification failed
            }
          }
        } catch (userError) {
          resetStats.failed++;
          console.error(`❌ [resetDailyLimits] Error processing user ${userId}:`, userError);
          resetStats.errors.push({
            userId: userId,
            error: userError.message,
          });
        }
      }

      // STEP 6: Log final stats
      const summary = `
        🏁 [resetDailyLimits] Completed
        📊 Processed: ${resetStats.processed}
        ✅ Reset: ${resetStats.reset}
        ❌ Failed: ${resetStats.failed}
        📲 Notified: ${resetStats.notified}
      `;
      console.log(summary);

      if (resetStats.failed > 0) {
        console.error(`⚠️  [resetDailyLimits] Errors encountered:`, resetStats.errors);
      }

      // Log overall execution
      await admin.firestore().collection('functionLogs').add({
        function: 'resetDailyLimits',
        timestamp: admin.firestore.Timestamp.now(),
        duration: 'auto',
        stats: resetStats,
        success: resetStats.failed === 0,
      });

      return {
        success: true,
        message: `Reset completed: ${resetStats.reset} users notified`,
        stats: resetStats,
      };
    } catch (error) {
      console.error('💥 [resetDailyLimits] CRITICAL ERROR:', error);

      // Log critical error for monitoring
      try {
        await admin.firestore().collection('functionLogs').add({
          function: 'resetDailyLimits',
          timestamp: admin.firestore.Timestamp.now(),
          status: 'CRITICAL_ERROR',
          error: error.message,
        });
      } catch (logError) {
        console.error('Failed to log critical error:', logError);
      }

      // Re-throw so Stackdriver alerts us
      throw error;
    }
  });
