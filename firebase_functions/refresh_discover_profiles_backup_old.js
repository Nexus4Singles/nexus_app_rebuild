/**
 * DAILY DISCOVER PROFILE REFRESH
 * 
 * Triggered daily (11 PM UTC) to refresh discover profiles for all dating users
 * 
 * Functionality:
 * 1. Runs every 24 hours at 11 PM UTC (scheduled via Firebase Scheduler)
 * 2. Fetches all users with active dating subscriptions
 * 3. Clears viewed profile history
 * 4. Updates refresh timestamp to trigger new segmentation
 * 5. Sends push notifications to users with new profiles available
 * 
 * SETUP INSTRUCTIONS:
 * 1. Deploy this function: firebase deploy --only functions:refreshDiscoverProfiles
 * 2. Set up Cloud Scheduler in Firebase Console:
 *    - Go to Cloud Scheduler
 *    - Create new job: "refresh-discover-profiles"
 *    - Frequency: "0 23 * * *" (11 PM UTC daily)
 *    - Timezone: UTC
 *    - Execution timeout: 540 seconds (9 minutes)
 *    - HTTP Target:
 *      URL: https://us-central1-nexus-visibility-app.cloudfunctions.net/refreshDiscoverProfiles
 *      Auth header: Add OIDC token
 *      Service account: Use default
 * 
 * DEPLOYMENT:
 * From root directory: firebase deploy --only functions:refreshDiscoverProfiles
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize if not already done in index.js
if (!admin.apps.length) {
  admin.initializeApp({
    storageBucket: 'nexus-visibility-app.appspot.com'
  });
}

const db = admin.firestore();

/**
 * HTTPS callable function for programmatic refresh
 * Can be called from Cloud Scheduler or manually
 */
exports.refreshDiscoverProfiles = functions.https.onRequest(
  async (req, res) => {
    try {
      console.log('Starting Discover profiles daily refresh...');

      // Verify request is from Cloud Scheduler or authorized source
      // (Cloud Scheduler adds Authorization header with service account token)
      const authHeader = req.get('Authorization');
      if (!authHeader && process.env.NODE_ENV === 'production') {
        return res.status(403).json({ error: 'Unauthorized' });
      }

      // Get all users subscribed to dating
      const usersSnapshot = await db
        .collectionGroup('userSettings')
        .where('interestedInDating', '==', true)
        .get();

      console.log(`Found ${usersSnapshot.docs.length} users interested in dating`);

      if (usersSnapshot.docs.length === 0) {
        return res.status(200).json({
          success: true,
          message: 'No users to refresh',
          usersRefreshed: 0,
          notificationsSent: 0,
        });
      }

      let usersRefreshed = 0;
      let notificationsSent = 0;
      const errors = [];

      // Process each user
      const promises = usersSnapshot.docs.map(async (userSettingsDoc) => {
        try {
          const uid = userSettingsDoc.ref.parent.parent.id;
          const userDoc = await db.collection('users').doc(uid).get();

          if (!userDoc.exists) {
            console.warn(`User ${uid} not found`);
            return;
          }

          // Get user's discover data
          const discoverDoc = await db
            .collection('users')
            .doc(uid)
            .collection('datingData')
            .doc('discover')
            .get();

          // Update discover refresh timestamp
          await db
            .collection('users')
            .doc(uid)
            .collection('datingData')
            .doc('discover')
            .update({
              lastRefreshTime: admin.firestore.FieldValue.serverTimestamp(),
              viewedProfileIds: [], // Clear viewed profiles for daily reset
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

          console.log(`Refreshed discover data for user: ${uid}`);
          usersRefreshed++;

          // Send push notification
          const fcmToken = userDoc.get('fcmToken');
          if (fcmToken) {
            try {
              await sendDiscoverRefreshNotification(uid, fcmToken, userDoc);
              notificationsSent++;
            } catch (notifError) {
              console.warn(`Failed to send notification to ${uid}:`, notifError.message);
              // Don't fail the whole operation if notification fails
            }
          }
        } catch (error) {
          const uid = userSettingsDoc.ref.parent.parent.id;
          console.error(`Error refreshing user ${uid}:`, error);
          errors.push({
            uid,
            error: error.message,
          });
        }
      });

      // Wait for all user refreshes to complete
      await Promise.all(promises);

      console.log(`Discover refresh completed: ${usersRefreshed} users refreshed, ${notificationsSent} notifications sent`);

      return res.status(200).json({
        success: true,
        message: 'Discover profiles refreshed successfully',
        usersRefreshed,
        notificationsSent,
        errors: errors.length > 0 ? errors : undefined,
      });
    } catch (error) {
      console.error('Error in refreshDiscoverProfiles:', error);
      return res.status(500).json({
        error: 'Internal server error',
        message: error.message,
      });
    }
  }
);

/**
 * OPTIONAL: Callable function for manual testing
 * Call from Flutter app for immediate refresh
 */
exports.refreshMyDiscoverProfiles = functions.https.onCall(
  async (data, context) => {
    try {
      // Verify user is authenticated
      if (!context.auth) {
        throw new functions.https.HttpsError(
          'unauthenticated',
          'Must be authenticated to refresh profiles'
        );
      }

      const uid = context.auth.uid;

      // Check if user is opted into dating
      const userSettingsDoc = await db
        .collection('users')
        .doc(uid)
        .collection('userSettings')
        .doc('settings')
        .get();

      if (!userSettingsDoc.exists || !userSettingsDoc.get('interestedInDating')) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'User is not subscribed to dating'
        );
      }

      // Check if user has already refreshed today (rate limit: 1 per hour)
      const discoverDoc = await db
        .collection('users')
        .doc(uid)
        .collection('datingData')
        .doc('discover')
        .get();

      if (discoverDoc.exists) {
        const lastRefresh = discoverDoc.get('lastRefreshTime')?.toDate();
        if (lastRefresh) {
          const hoursSinceRefresh = (Date.now() - lastRefresh.getTime()) / (1000 * 60 * 60);
          if (hoursSinceRefresh < 1) {
            throw new functions.https.HttpsError(
              'resource-exhausted',
              `Please wait ${Math.ceil(60 - hoursSinceRefresh)} minutes before refreshing again`
            );
          }
        }
      }

      // Perform refresh
      await db
        .collection('users')
        .doc(uid)
        .collection('datingData')
        .doc('discover')
        .update({
          lastRefreshTime: admin.firestore.FieldValue.serverTimestamp(),
          viewedProfileIds: [],
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      // Get user data for notification
      const userDoc = await db.collection('users').doc(uid).get();

      // Send notification
      const fcmToken = userDoc.get('fcmToken');
      if (fcmToken) {
        await sendDiscoverRefreshNotification(uid, fcmToken, userDoc);
      }

      return {
        success: true,
        message: 'Discover profiles refreshed successfully',
        refreshedAt: new Date().toISOString(),
      };
    } catch (error) {
      console.error('Error in refreshMyDiscoverProfiles:', error);
      throw error;
    }
  }
);

/**
 * Helper function to send push notification for new profiles
 */
async function sendDiscoverRefreshNotification(uid, fcmToken, userDoc) {
  // Count profiles available for this user to include in notification
  try {
    // This is simplified - in production, you might want to count actual profiles
    // or fetch from a cache for performance
    const profileCount = Math.floor(Math.random() * 8) + 3; // 3-10 profiles simulated

    const message = {
      notification: {
        title: '🎉 New Profiles Available!',
        body: 'Discover new matches today',
      },
      data: {
        type: 'discover_refresh',
        profileCount: profileCount.toString(),
        timestamp: new Date().toISOString(),
      },
      token: fcmToken,
      webpush: {
        notification: {
          title: '🎉 New Profiles Available!',
          body: 'Discover new matches today',
          icon: 'https://nexus-visibility-app.appspot.com/icons/notification_icon.png',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        data: {
          type: 'discover_refresh',
          profileCount: profileCount.toString(),
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: '🎉 New Profiles Available!',
              body: 'Discover new matches today',
            },
            sound: 'default',
            badge: '1',
          },
        },
        headers: {
          'apns-priority': '10',
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log(`Notification sent to ${uid}:`, response);

    // Log notification in user's activity for analytics
    await db
      .collection('users')
      .doc(uid)
      .collection('activity')
      .add({
        type: 'discover_refresh_notification',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        profileCount,
      });

    return response;
  } catch (error) {
    console.error(`Failed to send notification to ${uid}:`, error);
    throw error;
  }
}

/**
 * OPTIONAL: Scheduled function (alternative to Cloud Scheduler)
 * Uncomment to use Firebase Cloud Scheduler via pubsub
 * NOTE: Only use ONE method - either Cloud Scheduler HTTP trigger above
 * or this pubsub trigger. Prefer HTTP trigger (more flexible, easier to debug)
 */
/*
exports.scheduledRefreshDiscoverProfiles = functions.pubsub
  .schedule('0 23 * * *') // 11 PM UTC daily
  .timeZone('UTC')
  .onRun(async (context) => {
    // Same logic as refreshDiscoverProfiles
    // Reuse the logic in a helper function to avoid duplication
    console.log('Scheduled refresh triggered');
    // ... implementation
  });
*/
