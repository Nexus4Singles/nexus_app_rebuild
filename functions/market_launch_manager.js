const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Initialize market configuration for a country
 * HTTP function that sets up the market collection with proper defaults
 * 
 * Call with: POST /initializeMarket?market=uk
 */
exports.initializeMarket = functions.https.onRequest(async (req, res) => {
  // Check for admin authentication (should add security rules in production)
  const market = req.query.market || 'uk';
  
  try {
    const db = admin.firestore();
    const marketRef = db.collection('markets').doc(market);
    
    // Check if market already exists
    const marketDoc = await marketRef.get();
    
    if (marketDoc.exists) {
      return res.json({
        success: true,
        message: `Market '${market}' already exists`,
        data: marketDoc.data(),
      });
    }
    
    // Create new market document with defaults
    const marketConfig = {
      country: getCountryName(market),
      phase: 'prelaunch',
      launchDate: null,
      approvedProfileCount: 0,
      gender: {
        male: 0,
        female: 0,
      },
      dailyNotificationTime: '09:00',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    await marketRef.set(marketConfig);
    
    res.json({
      success: true,
      message: `Market '${market}' initialized successfully`,
      data: marketConfig,
    });
  } catch (error) {
    console.error('Error initializing market:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to initialize market',
      error: error.message,
    });
  }
});

/**
 * Get country name from market code
 */
function getCountryName(market) {
  const countries = {
    uk: 'United Kingdom',
    nigeria: 'Nigeria',
    ghana: 'Ghana',
  };
  return countries[market.toLowerCase()] || market;
}

/**
 * Send 14-day waitlist reminder notifications
 * Triggered daily at 9:15 AM UTC via Cloud Scheduler
 */
exports.send_waitlist_reminder_14day = functions.pubsub
  .schedule('15 9 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      const db = admin.firestore();
      
      // Calculate 14 days ago from now
      const fourteenDaysAgo = new Date();
      fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14);
      
      // Query users who:
      // 1. Have been on waitlist for 14+ days
      // 2. Are verified (verificationStatus = 'verified')
      // 3. Are in prelaunch market
      // 4. Haven't received a reminder today
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const usersSnapshot = await db
        .collection('users')
        .where('verificationStatus', '==', 'verified')
        .where('joinedWaitlistAt', '<', admin.firestore.Timestamp.fromDate(fourteenDaysAgo))
        .where('lastReminderSentAt', '<', admin.firestore.Timestamp.fromDate(today))
        .limit(500) // Batch process to avoid timeout
        .get();
      
      let sentCount = 0;
      
      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        
        try {
          // Send notification via FCM if user has device tokens
          const user = userDoc.data();
          
          if (user.fcmTokens && Array.isArray(user.fcmTokens) && user.fcmTokens.length > 0) {
            const message = {
              notification: {
                title: 'Your Profile is Ready! 🚀',
                body: 'The dating market is launching soon. We can\'t wait for you to meet amazing people!',
              },
              data: {
                action: 'open_waiting_list',
                screen: 'search_results',
              },
            };
            
            await admin.messaging().sendMulticast({
              tokens: user.fcmTokens,
              ...message,
            });
          }
          
          // Update lastReminderSentAt timestamp
          await db.collection('users').doc(userId).update({
            lastReminderSentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          sentCount++;
        } catch (error) {
          console.warn(`Failed to send reminder to user ${userId}:`, error.message);
        }
      }
      
      console.log(`Sent waitlist reminders to ${sentCount} users`);
      return { success: true, sentCount };
    } catch (error) {
      console.error('Error in send_waitlist_reminder_14day:', error);
      throw error;
    }
  });

/**
 * Market launch handler - called when admin triggers launch
 * Scheduled launch uses Cloud Scheduler, immediate launch uses HTTP trigger
 */
exports.executeMarketLaunch = functions.https.onCall(async (data, context) => {
  try {
    // Check admin access
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    const db = admin.firestore();
    const market = data.market || 'uk';
    
    // Verify admin access (implement your own logic)
    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    if (!userDoc.data()?.isAdmin) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }
    
    const marketRef = db.collection('markets').doc(market);
    
    // Update market phase to active
    await marketRef.update({
      phase: 'active',
      launchDate: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Send launch notification to all users on waitlist
    const usersSnapshot = await db
      .collection('users')
      .where('verificationStatus', '==', 'verified')
      .limit(1000)
      .get();
    
    const notificationBatch = [];
    for (const userDoc of usersSnapshot.docs) {
      const user = userDoc.data();
      if (user.fcmTokens && Array.isArray(user.fcmTokens)) {
        notificationBatch.push({
          tokens: user.fcmTokens,
          notification: {
            title: 'Market Launched! 🎉',
            body: 'Meet your daily matches now!',
          },
          data: {
            action: 'open_daily_profiles',
            screen: 'search_results',
          },
        });
      }
    }
    
    // Send notifications in batches
    for (const batch of notificationBatch) {
      if (batch.tokens.length > 0) {
        await admin.messaging().sendMulticast(batch);
      }
    }
    
    return {
      success: true,
      message: `Market '${market}' launched successfully`,
    };
  } catch (error) {
    console.error('Error executing market launch:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
