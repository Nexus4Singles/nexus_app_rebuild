/**
 * NEXUS 2.0 - CLOUD FUNCTIONS
 * 
 * This file contains Firebase Cloud Functions for the Nexus app.
 * 
 * SETUP INSTRUCTIONS:
 * 1. Run: firebase init functions (in your nexus_app directory)
 * 2. Copy this file to functions/index.js
 * 3. Run: cd functions && npm install nodemailer
 * 4. Set Gmail App Password: firebase functions:config:set gmail.password="YOUR_APP_PASSWORD"
 * 5. Deploy: firebase deploy --only functions
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const { Parser } = require('json2csv');

admin.initializeApp({
  storageBucket: 'nexus-visibility-app.appspot.com'
});

// ============================================================================
// EMAIL CONFIGURATION
// ============================================================================

// Gmail transporter - requires App Password (not regular password)
// To get App Password:
// 1. Enable 2FA on your Google account
// 2. Go to myaccount.google.com → Security → App passwords
// 3. Create new app password for "Mail"
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'nexusgodlydating@gmail.com',
    pass: functions.config().gmail?.password || process.env.GMAIL_APP_PASSWORD,
  },
});

// ============================================================================
// SUPPORT REQUEST EMAIL FUNCTION
// ============================================================================

/**
 * Triggered when a new document is created in the 'supportRequests' collection.
 * Sends a formatted email to the support team.
 */
exports.onSupportRequestCreated = functions.firestore
  .document('supportRequests/{requestId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const requestId = context.params.requestId;
    
    console.log(`Processing support request: ${requestId}`);
    
    // Format the date
    let submittedDate = 'N/A';
    if (data.createdAt) {
      try {
        submittedDate = new Date(data.createdAt.toDate()).toLocaleString('en-US', {
          weekday: 'long',
          year: 'numeric',
          month: 'long',
          day: 'numeric',
          hour: '2-digit',
          minute: '2-digit',
          timeZoneName: 'short'
        });
      } catch (e) {
        submittedDate = 'N/A';
      }
    }
    
    // Email content
    const mailOptions = {
      from: '"Nexus Support System" <nexusgodlydating@gmail.com>',
      to: 'nexusgodlydating@gmail.com',
      replyTo: data.userEmail || 'noreply@nexusapp.com',
      subject: `[Nexus Support] ${data.category}: ${data.subject}`,
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="margin: 0; padding: 0; font-family: 'Segoe UI', Arial, sans-serif; background-color: #f5f5f5;">
          <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
            
            <!-- Header -->
            <div style="background: linear-gradient(135deg, #BA223C 0%, #D64A60 100%); padding: 30px; border-radius: 16px 16px 0 0; text-align: center;">
              <h1 style="color: white; margin: 0; font-size: 28px; font-weight: 700;">📬 New Support Request</h1>
              <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 14px;">A user needs your help</p>
            </div>
            
            <!-- User Info Card -->
            <div style="background: white; padding: 25px; border-left: 1px solid #e0e0e0; border-right: 1px solid #e0e0e0;">
              <div style="display: flex; align-items: center; margin-bottom: 20px;">
                <div style="width: 50px; height: 50px; background: linear-gradient(135deg, #BA223C, #D64A60); border-radius: 50%; display: flex; align-items: center; justify-content: center; color: white; font-size: 20px; font-weight: bold;">
                  ${(data.username || 'U').charAt(0).toUpperCase()}
                </div>
                <div style="margin-left: 15px;">
                  <div style="font-size: 18px; font-weight: 600; color: #333;">${data.username || 'Unknown User'}</div>
                  <div style="font-size: 14px; color: #666;">${data.userEmail || 'No email provided'}</div>
                </div>
              </div>
              
              <!-- Info Grid -->
              <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
                <tr>
                  <td style="padding: 10px 0; border-bottom: 1px solid #f0f0f0; color: #888; font-size: 13px; width: 120px;">Request ID</td>
                  <td style="padding: 10px 0; border-bottom: 1px solid #f0f0f0; font-family: monospace; font-size: 12px; color: #666;">${requestId}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; border-bottom: 1px solid #f0f0f0; color: #888; font-size: 13px;">User ID</td>
                  <td style="padding: 10px 0; border-bottom: 1px solid #f0f0f0; font-family: monospace; font-size: 12px; color: #666;">${data.userId || 'N/A'}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; border-bottom: 1px solid #f0f0f0; color: #888; font-size: 13px;">Category</td>
                  <td style="padding: 10px 0; border-bottom: 1px solid #f0f0f0;">
                    <span style="background: #BA223C; color: white; padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: 500;">${data.category || 'General'}</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; border-bottom: 1px solid #f0f0f0; color: #888; font-size: 13px;">Platform</td>
                  <td style="padding: 10px 0; border-bottom: 1px solid #f0f0f0; color: #333;">${data.platform || 'N/A'}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; border-bottom: 1px solid #f0f0f0; color: #888; font-size: 13px;">App Version</td>
                  <td style="padding: 10px 0; border-bottom: 1px solid #f0f0f0; color: #333;">${data.appVersion || 'N/A'}</td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; color: #888; font-size: 13px;">Submitted</td>
                  <td style="padding: 10px 0; color: #333;">${submittedDate}</td>
                </tr>
              </table>
            </div>
            
            <!-- Subject & Message -->
            <div style="background: #fafafa; padding: 25px; border-left: 1px solid #e0e0e0; border-right: 1px solid #e0e0e0;">
              <h3 style="color: #333; margin: 0 0 10px 0; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px;">Subject</h3>
              <p style="color: #333; font-size: 18px; font-weight: 600; margin: 0 0 25px 0;">${data.subject || 'No subject'}</p>
              
              <h3 style="color: #333; margin: 0 0 10px 0; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px;">Message</h3>
              <div style="background: white; padding: 20px; border-radius: 10px; border: 1px solid #e8e8e8; white-space: pre-wrap; line-height: 1.6; color: #444;">${data.message || 'No message'}</div>
            </div>
            
            <!-- Footer -->
            <div style="background: #333; padding: 20px; border-radius: 0 0 16px 16px; text-align: center;">
              <p style="margin: 0 0 10px 0; color: rgba(255,255,255,0.9); font-size: 14px;">
                💡 <strong>Reply directly</strong> to this email to respond to the user
              </p>
              <p style="margin: 0; color: rgba(255,255,255,0.6); font-size: 12px;">
                Nexus Support System • nexusgodlydating@gmail.com
              </p>
            </div>
            
          </div>
        </body>
        </html>
      `,
      // Plain text version
      text: `
NEW SUPPORT REQUEST
==================

Request ID: ${requestId}
Username: ${data.username || 'N/A'}
Email: ${data.userEmail || 'N/A'}
User ID: ${data.userId || 'N/A'}
Category: ${data.category || 'N/A'}
Platform: ${data.platform || 'N/A'}
App Version: ${data.appVersion || 'N/A'}
Submitted: ${submittedDate}

SUBJECT
-------
${data.subject || 'No subject'}

MESSAGE
-------
${data.message || 'No message'}

---
Reply to this email to respond to the user.
      `
    };
    
    try {
      // Send email
      await transporter.sendMail(mailOptions);
      console.log(`✅ Support email sent successfully for request: ${requestId}`);
      
      // Update the document to mark email as sent
      await snapshot.ref.update({
        emailSent: true,
        emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return { success: true, requestId };
      
    } catch (error) {
      console.error(`❌ Error sending support email for ${requestId}:`, error);
      
      // Update the document with error info
      await snapshot.ref.update({
        emailSent: false,
        emailError: error.message,
      });
      
      return { success: false, error: error.message };
    }
  });

// ============================================================================
// OPTIONAL: WELCOME EMAIL FUNCTION
// ============================================================================

/**
 * Sends a welcome email when a new user signs up.
 * Triggered when a new document is created in the 'users' collection.
 */
exports.onUserCreated = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const userId = context.params.userId;
    
    // Only send if user has email
    if (!data.email) {
      console.log(`Skipping welcome email for ${userId} - no email`);
      return null;
    }
    
    const mailOptions = {
      from: '"Nexus Team" <nexusgodlydating@gmail.com>',
      to: data.email,
      subject: 'Welcome to Nexus! 🎉',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: linear-gradient(135deg, #BA223C, #D64A60); padding: 40px 30px; border-radius: 16px 16px 0 0; text-align: center;">
            <h1 style="color: white; margin: 0; font-size: 32px;">Welcome to Nexus!</h1>
          </div>
          
          <div style="background: white; padding: 30px; border: 1px solid #e0e0e0;">
            <p style="font-size: 16px; color: #333; line-height: 1.6;">
              Hi ${data.fullName || data.username || 'there'}! 👋
            </p>
            
            <p style="font-size: 16px; color: #333; line-height: 1.6;">
              We're thrilled to have you join the Nexus community. You've taken an important step in your journey towards building a godly relationship.
            </p>
            
            <p style="font-size: 16px; color: #333; line-height: 1.6;">
              Here's what you can do next:
            </p>
            
            <ul style="font-size: 16px; color: #333; line-height: 1.8;">
              <li>Complete your profile to get better matches</li>
              <li>Take the compatibility quiz</li>
              <li>Explore our journey packages for personal growth</li>
              <li>Check out weekly stories and polls</li>
            </ul>
            
            <p style="font-size: 16px; color: #333; line-height: 1.6;">
              If you have any questions, feel free to reach out to us at nexusgodlydating@gmail.com.
            </p>
            
            <p style="font-size: 16px; color: #333; line-height: 1.6;">
              Blessings,<br>
              <strong>The Nexus Team</strong>
            </p>
          </div>
          
          <div style="background: #f5f5f5; padding: 20px; text-align: center; border-radius: 0 0 16px 16px;">
            <p style="margin: 0; color: #666; font-size: 12px;">
              © ${new Date().getFullYear()} Nexus • Building Godly Relationships
            </p>
          </div>
        </div>
      `
    };
    
    try {
      await transporter.sendMail(mailOptions);
      console.log(`✅ Welcome email sent to ${data.email}`);
      return { success: true };
    } catch (error) {
      console.error(`❌ Error sending welcome email:`, error);
      return { success: false, error: error.message };
    }
  });

// ============================================================================
// USER DELETION - AUTH SYNC FUNCTION
// ============================================================================

/**
 * Automatically deletes the Firebase Auth user when their Firestore document is deleted.
 * This ensures that Firestore and Auth stay in sync.
 * 
 * Triggered when a document is deleted from the 'users' collection.
 */
exports.onUserDeleted = functions.firestore
  .document('users/{userId}')
  .onDelete(async (snapshot, context) => {
    const userId = context.params.userId;
    const userData = snapshot.data();
    
    console.log(`🗑️  User document deleted: ${userId} (${userData?.email || 'no email'})`);
    
    try {
      // Delete the user from Firebase Authentication
      await admin.auth().deleteUser(userId);
      console.log(`✅ Firebase Auth user deleted: ${userId}`);
      
      // Optional: Send account deletion confirmation email
      if (userData?.email) {
        const mailOptions = {
          from: '"Nexus Team" <nexusgodlydating@gmail.com>',
          to: userData.email,
          subject: 'Account Deletion Confirmation',
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <div style="background: #f5f5f5; padding: 30px; border-radius: 16px;">
                <h2 style="color: #333; margin-top: 0;">Account Deleted</h2>
                <p style="font-size: 16px; color: #666; line-height: 1.6;">
                  Your Nexus account has been successfully deleted as requested.
                </p>
                <p style="font-size: 16px; color: #666; line-height: 1.6;">
                  All your data has been removed from our system.
                </p>
                <p style="font-size: 16px; color: #666; line-height: 1.6;">
                  If you didn't request this deletion or have any questions, 
                  please contact us at nexusgodlydating@gmail.com.
                </p>
                <p style="font-size: 14px; color: #999; margin-top: 30px;">
                  The Nexus Team
                </p>
              </div>
            </div>
          `
        };
        
        try {
          await transporter.sendMail(mailOptions);
          console.log(`✅ Deletion confirmation email sent to ${userData.email}`);
        } catch (emailError) {
          console.error(`⚠️  Failed to send deletion email:`, emailError.message);
          // Don't fail the entire function if email fails
        }
      }
      
      return { success: true, userId };
    } catch (error) {
      console.error(`❌ Error deleting Firebase Auth user ${userId}:`, error);
      
      // If user doesn't exist in Auth (already deleted), that's okay
      if (error.code === 'auth/user-not-found') {
        console.log(`ℹ️  User ${userId} not found in Firebase Auth (already deleted)`);
        return { success: true, userId, note: 'User already deleted from Auth' };
      }
      
      // For other errors, log but don't throw (Firestore deletion already completed)
      return { success: false, userId, error: error.message };
    }
  });

// ============================================================================
// PUSH NOTIFICATIONS: FCM SERVICE
// ============================================================================

/**
 * Send FCM push notification when notification document is created
 * Triggers on: users/{userId}/notifications/{notificationId}
 * 
 * This Cloud Function:
 * 1. Listens for new notification records created by the app
 * 2. Retrieves the user's FCM token from Firestore
 * 3. Sends an FCM message to that token using the admin SDK
 * 4. Updates the notification record with sent status
 */
exports.sendPushNotification = functions.firestore
  .document('users/{userId}/notifications/{notificationId}')
  .onCreate(async (snapshot, context) => {
    const { userId, notificationId } = context.params;
    const notification = snapshot.data();

    try {
      // Get user's FCM token
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      const userData = userDoc.data();
      
      if (!userData || !userData.fcmToken) {
        console.log(`⚠️ No FCM token found for user: ${userId}`);
        // Mark as sent anyway so we don't retry infinitely
        await admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({
            isSent: true,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            sendError: 'No FCM token found',
          });
        return null;
      }

      // Handle both string token and object token formats for compatibility
      const fcmToken = typeof userData.fcmToken === 'string' 
        ? userData.fcmToken 
        : userData.fcmToken.token;

      if (!fcmToken) {
        console.log(`⚠️ FCM token is empty for user: ${userId}`);
        await admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({
            isSent: true,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            sendError: 'FCM token is empty',
          });
        return null;
      }

      const payload = notification.payload || {};
      const notificationType = payload.type || 'system';

      // Determine priority based on notification type
      const isHighPriority = 
        notificationType === 'profile_pending_verification' ||
        notificationType === 'profile_rejected' ||
        notificationType === 'profile_verified' ||
        notificationType === 'subscription_activated' ||
        notificationType === 'new_message';

      // Build FCM message with platform-specific configurations
      const message = {
        token: fcmToken,
        notification: {
          title: payload.title || 'Nexus',
          body: payload.body || '',
        },
        android: {
          priority: isHighPriority ? 'high' : 'normal',
          notification: {
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            sound: 'default',
            channelId: 'nexus_default_channel',
            icon: '@mipmap/ic_launcher',
          },
        },
        webpush: {
          headers: {
            TTL: '3600',
          },
          notification: {
            icon: '@mipmap/ic_launcher',
            badge: '@mipmap/ic_launcher',
          },
        },
        apns: {
          headers: {
            'apns-priority': isHighPriority ? '10' : '10',
          },
          payload: {
            aps: {
              alert: {
                title: payload.title || 'Nexus',
                body: payload.body || '',
              },
              badge: 1,
              sound: 'default',
            },
          },
        },
      };

      // Add custom data fields
      if (payload && typeof payload === 'object') {
        message.data = {};
        for (const [key, value] of Object.entries(payload)) {
          if (key !== 'title' && key !== 'body' && key !== 'type') {
            message.data[key] = String(value);
          }
        }
      }

      console.log(`📤 Sending FCM to user ${userId}:`, {
        token: fcmToken.substring(0, 20) + '...',
        type: notificationType,
        title: payload.title,
      });

      // Send message
      const response = await admin.messaging().send(message);
      console.log(`✅ FCM sent successfully: ${response}`);

      // Update notification as sent
      await admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({
          isSent: true,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          fcmMessageId: response,
        });

      return { success: true, messageId: response };

    } catch (error) {
      console.error(`❌ Error sending FCM to user ${userId}:`, error);

      try {
        // Update notification with error
        await admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({
            isSent: false,
            sendError: error.message,
            lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      } catch (updateError) {
        console.error(`❌ Failed to update notification error status:`, updateError);
      }

      // Log specific error types
      if (error.code === 'messaging/invalid-argument') {
        console.error(`⚠️ Invalid FCM token for user ${userId}`);
      } else if (error.code === 'messaging/mismatched-credential') {
        console.error(`⚠️ Firebase credentials mismatch`);
      } else if (error.code === 'messaging/registration-token-not-registered') {
        console.error(`⚠️ FCM token not registered: ${userId}`);
      }

      return null;
    }
  });

// ============================================================================
// PUSH NOTIFICATIONS: TEST FCM MESSAGE (SINGLE DEVICE)
// ============================================================================

/**
 * CALLABLE HTTP FUNCTION - Test FCM to a specific user
 * 
 * This function lets you send a test notification to a single user without
 * creating a Firestore document. Perfect for testing before mass messaging.
 * 
 * Usage from client:
 * const functions = firebase.functions();
 * const testFCM = functions.httpsCallable('testSendNotification');
 * await testFCM({
 *   userId: 'user123',
 *   title: 'Test Message',
 *   body: 'This is a test notification',
 *   type: 'test_message'
 * });
 * 
 * Usage from Firebase Console terminal:
 * firebase functions:shell
 * testSendNotification({
 *   userId: 'your-user-id',
 *   title: 'Test Title',
 *   body: 'Test Body'
 * })
 */
exports.testSendNotification = functions.https.onCall(async (data, context) => {
  // Optional: Require authentication (uncomment to enable)
  // if (!context.auth) {
  //   throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  // }

  const { userId, title = 'Test Message', body = 'This is a test', type = 'test_message' } = data;

  if (!userId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'userId is required'
    );
  }

  try {
    console.log(`🧪 TEST: Sending FCM to user: ${userId}`);

    // Get user's FCM token
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (!userData || !userData.fcmToken) {
      throw new functions.https.HttpsError(
        'not-found',
        `No FCM token found for user: ${userId}. Make sure they're logged in on the device.`
      );
    }

    const fcmToken = typeof userData.fcmToken === 'string' 
      ? userData.fcmToken 
      : userData.fcmToken.token;

    if (!fcmToken) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `FCM token is empty for user: ${userId}`
      );
    }

    // Build FCM message
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      android: {
        priority: 'high',
        notification: {
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          sound: 'default',
          channelId: 'nexus_default_channel',
          icon: '@mipmap/ic_launcher',
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            badge: 1,
            sound: 'default',
          },
        },
      },
      data: {
        type: type,
        timestamp: new Date().toISOString(),
      },
    };

    console.log(`📤 Sending test FCM:`, {
      token: fcmToken.substring(0, 20) + '...',
      title,
      body,
    });

    // Send message
    const response = await admin.messaging().send(message);
    
    console.log(`✅ Test FCM sent successfully: ${response}`);

    return {
      success: true,
      messageId: response,
      userId,
      title,
      body,
      message: `✅ Test notification sent to ${userId}. Check your device!`,
    };

  } catch (error) {
    console.error(`❌ Error sending test FCM:`, error);

    // Provide helpful error messages
    if (error.code === 'messaging/invalid-argument') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Invalid FCM token for user ${userId}. Token may have expired.`
      );
    } else if (error.code === 'messaging/registration-token-not-registered') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `FCM token not registered. User may need to reinstall the app.`
      );
    } else {
      throw new functions.https.HttpsError(
        'internal',
        `Failed to send test notification: ${error.message}`
      );
    }
  }
});

// ============================================================================
// MARKETING: WEEKLY USER REPORT
// ============================================================================

/**
 * Scheduled Cloud Function that runs every Monday at 9 AM UTC
 * Generates a CSV report of new users from the past 7 days
 * Report includes: email, username, nationality, country of residence
 * Stores the CSV file in Cloud Storage for download
 */
exports.weeklyUserReport = functions.pubsub
  .schedule('0 9 * * 1')  // Google Cloud Scheduler cron: Monday at 9 AM UTC
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      console.log('🚀 Starting weekly user report generation...');
      
      // Calculate date range (past 7 days)
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
      
      console.log(`📅 Querying users created since: ${sevenDaysAgo.toISOString()}`);
      
      // Query users created in past 7 days
      const snapshot = await admin.firestore()
        .collection('users')
        .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(sevenDaysAgo))
        .orderBy('createdAt', 'desc')
        .get();
      
      if (snapshot.empty) {
        console.log('ℹ️  No new users this week');
        return { success: true, message: 'No new users this week', usersCount: 0 };
      }
      
      console.log(`✅ Found ${snapshot.size} new users`);
      
      // Map user data to CSV format
      const users = [];
      snapshot.forEach(doc => {
        const userData = doc.data();
        users.push({
          email: userData.email || 'N/A',
          username: userData.username || 'N/A',
          nationality: userData.dating?.profile?.nationality || userData.nationality || 'N/A',
          countryOfResidence: userData.dating?.profile?.country || userData.country || 'N/A',
          dateJoined: userData.createdAt 
            ? userData.createdAt.toDate().toISOString().split('T')[0]  // ISO format: YYYY-MM-DD
            : 'N/A',
          createdAt: userData.createdAt
            ? userData.createdAt.toDate().toISOString()
            : new Date().toISOString(),
        });
      });
      
      console.log('📝 Converting to CSV format...');
      
      // Convert to CSV
      const json2csvParser = new Parser({
        fields: [
          'email',
          'username',
          'nationality',
          'countryOfResidence',
          'dateJoined',
          'createdAt'
        ]
      });
      const csv = json2csvParser.parse(users);
      
      // Generate filename with current date
      const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
      const filename = `user-reports/new-users-${today}.csv`;
      
      console.log(`💾 Uploading to Cloud Storage: ${filename}`);
      
      // Upload to Cloud Storage
      const bucket = admin.storage().bucket();
      const file = bucket.file(filename);
      
      await file.save(csv, {
        metadata: {
          contentType: 'text/csv',
          cacheControl: 'public, max-age=3600',
        },
      });
      
      console.log(`✅ Report successfully uploaded: ${filename}`);
      console.log(`📊 Total new users: ${users.length}`);
      
      return {
        success: true,
        message: 'Weekly user report generated successfully',
        usersCount: users.length,
        filename,
        period: `${sevenDaysAgo.toLocaleDateString()} - ${new Date().toLocaleDateString()}`,
      };
      
    } catch (error) {
      console.error('❌ Error generating weekly user report:', error);
      throw error;
    }
  });

// ============================================================================
// COACH APPLICATION EMAIL FUNCTION
// ============================================================================

/**
 * Triggered when a new document is created in the 'coachApplications' collection.
 * Sends a comprehensive email to contact@nexus4singles.com with all application details
 * and attachments (profile photo + credentials PDF if provided).
 */
exports.onCoachApplicationSubmitted = functions.firestore
  .document('coachApplications/{applicationId}')
  .onCreate(async (snapshot, context) => {
    try {
      const data = snapshot.data();
      const applicationId = context.params.applicationId;
      const userId = data.userId;  // Get userId from stored data
      const bucket = admin.storage().bucket();

      console.log(`📝 Processing coach application: ${applicationId} from user: ${userId}`);

      // Download attachments from Storage
      let attachments = [];

      // Download profile photo from coaches/{userId}/ folder
      if (data.profilePhoto?.url) {
        try {
          // List files in coaches/{userId}/ to find profile photo
          const [files] = await bucket.getFiles({
            prefix: `coaches/${userId}/profile_photo_`,
          });

          if (files.length > 0) {
            // Get the most recent profile photo (sorted by name which includes timestamp)
            const photoFile = files.sort((a, b) => b.name.localeCompare(a.name))[0];
            const photoContent = await photoFile.download();
            attachments.push({
              filename: data.profilePhoto.filename || 'profile-photo.jpg',
              content: photoContent[0],
              contentType: 'image/jpeg',
            });
            console.log('✅ Profile photo downloaded from:', photoFile.name);
          } else {
            console.warn('⚠️  Profile photo file not found in storage');
          }
        } catch (err) {
          console.warn('⚠️  Could not download profile photo:', err.message);
        }
      }

      // Download credentials PDF from coaches/{userId}/ folder
      if (data.credentialsPdf?.url) {
        try {
          // List files in coaches/{userId}/ to find credentials PDF
          const [files] = await bucket.getFiles({
            prefix: `coaches/${userId}/credentials_`,
          });

          if (files.length > 0) {
            // Get the most recent credentials file (sorted by name which includes timestamp)
            const pdfFile = files.sort((a, b) => b.name.localeCompare(a.name))[0];
            const pdfContent = await pdfFile.download();
            attachments.push({
              filename: 'credentials.pdf',
              content: pdfContent[0],
              contentType: 'application/pdf',
            });
            console.log('✅ Credentials PDF downloaded from:', pdfFile.name);
          } else {
            console.warn('⚠️  Credentials PDF file not found in storage');
          }
        } catch (err) {
          console.warn('⚠️  Could not download credentials PDF:', err.message);
        }
      }

      // Format application data for email
      const applicationDetails = `
Full Name: ${data.fullName || 'N/A'}
Email: ${data.email || 'N/A'}
Phone: ${data.phoneNumber || 'N/A'}
Gender: ${data.gender || 'N/A'}
Nationality: ${data.nationality || 'N/A'}
Residence: ${data.residenceLocation || 'N/A'}
Title: ${data.title || 'N/A'}
Years of Experience: ${data.yearsOfExperience || 'N/A'}
Marital Status: ${data.maritalStatus || 'N/A'}

CREDENTIALS & EXPERTISE:
${data.credentials || 'N/A'}

COACHING PHILOSOPHY:
${data.coachingPhilosophy || 'N/A'}

SOCIAL MEDIA:
Instagram: ${data.instagramHandle || 'Not provided'}
LinkedIn: ${data.linkedinProfile || 'Not provided'}

---
Application ID: ${applicationId}
Submitted: ${new Date(data.submittedAt.toDate()).toLocaleString()}
Status: ${data.status}
      `;

      // Prepare email
      const mailOptions = {
        from: 'nexusgodlydating@gmail.com',
        to: 'contact@nexus4singles.com',
        cc: 'contact@nexus4singles.com', // CC to ensure receipt
        subject: `🎯 New Coach Application: ${data.fullName}`,
        text: `New marriage counselor application received.\n\n${applicationDetails}`,
        html: `
          <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #333;">
            <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 24px; border-radius: 8px 8px 0 0; text-align: center;">
              <h1 style="margin: 0; font-size: 24px;">🎯 New Coach Application</h1>
              <p style="margin: 8px 0 0 0; font-size: 14px; opacity: 0.9;">Review applicant details below</p>
            </div>
            
            <div style="background: #f9fafb; padding: 24px; border-radius: 0 0 8px 8px; border: 1px solid #e5e7eb;">
              <h2 style="margin: 0 0 16px 0; font-size: 18px; color: #111;">Applicant Information</h2>
              
              <table style="width: 100%; margin-bottom: 24px; border-collapse: collapse;">
                <tr style="border-bottom: 1px solid #e5e7eb;">
                  <td style="padding: 12px 0; font-weight: 600; width: 40%; color: #667eea;">Name:</td>
                  <td style="padding: 12px 0;">${data.fullName || 'N/A'}</td>
                </tr>
                <tr style="border-bottom: 1px solid #e5e7eb;">
                  <td style="padding: 12px 0; font-weight: 600; color: #667eea;">Email:</td>
                  <td style="padding: 12px 0;"><a href="mailto:${data.email}" style="color: #667eea; text-decoration: none;">${data.email || 'N/A'}</a></td>
                </tr>
                <tr style="border-bottom: 1px solid #e5e7eb;">
                  <td style="padding: 12px 0; font-weight: 600; color: #667eea;">Phone:</td>
                  <td style="padding: 12px 0;">${data.phoneNumber || 'N/A'}</td>
                </tr>
                <tr style="border-bottom: 1px solid #e5e7eb;">
                  <td style="padding: 12px 0; font-weight: 600; color: #667eea;">Location:</td>
                  <td style="padding: 12px 0;">${data.residenceLocation || 'N/A'}</td>
                </tr>
                <tr style="border-bottom: 1px solid #e5e7eb;">
                  <td style="padding: 12px 0; font-weight: 600; color: #667eea;">Experience:</td>
                  <td style="padding: 12px 0;">${data.yearsOfExperience || 0} years</td>
                </tr>
                <tr>
                  <td style="padding: 12px 0; font-weight: 600; color: #667eea;">Status:</td>
                  <td style="padding: 12px 0;">${data.maritalStatus || 'N/A'}</td>
                </tr>
              </table>

              <h3 style="margin: 16px 0 12px 0; font-size: 16px; color: #111;">Professional Background</h3>
              <p style="margin: 0 0 16px 0; padding: 12px; background: white; border-left: 4px solid #667eea; border-radius: 4px; color: #555; line-height: 1.6;">
                <strong>Credentials:</strong><br>${data.credentials || 'Not provided'}
              </p>

              <h3 style="margin: 16px 0 12px 0; font-size: 16px; color: #111;">Coaching Philosophy</h3>
              <p style="margin: 0 0 16px 0; padding: 12px; background: white; border-left: 4px solid #764ba2; border-radius: 4px; color: #555; line-height: 1.6;">
                ${data.coachingPhilosophy || 'Not provided'}
              </p>

              ${data.instagramHandle || data.linkedinProfile ? `
              <h3 style="margin: 16px 0 12px 0; font-size: 16px; color: #111;">Social Media</h3>
              <ul style="margin: 0 0 16px 0; padding-left: 20px;">
                ${data.instagramHandle ? `<li style="margin-bottom: 8px;"><strong>Instagram:</strong> ${data.instagramHandle}</li>` : ''}
                ${data.linkedinProfile ? `<li><strong>LinkedIn:</strong> <a href="${data.linkedinProfile}" style="color: #667eea;">${data.linkedinProfile}</a></li>` : ''}
              </ul>
              ` : ''}

              <hr style="margin: 24px 0; border: none; border-top: 1px solid #e5e7eb;">
              
              <div style="background: white; padding: 12px; border-radius: 4px; font-size: 12px; color: #666;">
                <strong>Application ID:</strong> ${applicationId}<br>
                <strong>Submitted:</strong> ${new Date(data.submittedAt.toDate()).toLocaleString()}<br>
                <strong>Status:</strong> <span style="color: #667eea; font-weight: 600;">PENDING REVIEW</span>
              </div>
            </div>

            <div style="padding: 16px; text-align: center; font-size: 12px; color: #999;">
              <p style="margin: 0;">This is an automated email from the Nexus coaching application system.</p>
            </div>
          </div>
        `,
        attachments: attachments,
      };

      // Send email
      await transporter.sendMail(mailOptions);
      console.log(`✅ Application email sent for ${data.fullName}`);

      // Update Firestore document with email sent timestamp and admin review status
      await snapshot.ref.update({
        emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending', // Set status to pending for admin review queue
      });

      return { success: true, applicationId };

    } catch (error) {
      console.error('❌ Error processing coach application:', error);
      throw new functions.https.HttpsError(
        'internal',
        `Failed to process application: ${error.message}`
      );
    }
  });

// ============================================================================
// POLL AGGREGATE RECALCULATION FUNCTION
// ============================================================================

/**
 * Recalculates poll aggregate from individual votes.
 * Used to fix corrupted aggregates where optionCounts don't match actual votes.
 * Can be called via HTTP: POST /recalculatePollAggregate?pollId=poll_week_01
 */
exports.recalculatePollAggregate = functions.https.onCall(async (data, context) => {
  const pollId = data.pollId;

  if (!pollId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'pollId is required'
    );
  }

  try {
    const db = admin.firestore();
    
    // Get all votes for this poll
    const votesSnapshot = await db
      .collection('pollVotes')
      .doc(pollId)
      .collection('votes')
      .get();

    console.log(`Found ${votesSnapshot.size} votes for poll ${pollId}`);

    // Calculate optionCounts from individual votes
    const optionCounts = {};
    votesSnapshot.forEach(doc => {
      const vote = doc.data();
      const optionId = vote.selectedOptionId;
      optionCounts[optionId] = (optionCounts[optionId] || 0) + 1;
    });

    const totalVotes = votesSnapshot.size;

    console.log(`Recalculated aggregate for ${pollId}:`, {
      optionCounts,
      totalVotes,
    });

    // Update the aggregate document
    await db.collection('pollAggregates').doc(pollId).update({
      optionCounts: optionCounts,
      totalVotes: totalVotes,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Successfully recalculated aggregate for ${pollId}`);

    return {
      success: true,
      pollId,
      optionCounts,
      totalVotes,
      message: `Fixed ${pollId}: ${totalVotes} votes across options`,
    };

  } catch (error) {
    console.error(`❌ Error recalculating poll ${pollId}:`, error);
    throw new functions.https.HttpsError(
      'internal',
      `Failed to recalculate aggregate: ${error.message}`
    );
  }
});

// ============================================================================
// JOURNEY CONTENT MANAGEMENT (Cloud-served JSON updates)
// ============================================================================

/**
 * Fetches journey JSON files directly from cloud storage
 * No app rebuild required - just upload new JSON to Storage!
 * 
 * Endpoint: GET /getJourney?category={category}&journeyId={journeyId}
 * Storage path: journeys/{category}/{journeyId}.json
 */
exports.getJourney = functions.https.onRequest((req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  (async () => {
    try {
      const { category, journeyId } = req.query;

      if (!category || !journeyId) {
        return res.status(400).json({
          error: 'Missing parameters',
          required: ['category', 'journeyId'],
          example: '?category=married&journeyId=married_journey_01_communication_conflict',
        });
      }

      const filePath = `journeys/${category}/${journeyId}.json`;
      const bucket = admin.storage().bucket();
      const file = bucket.file(filePath);
      const [exists] = await file.exists();

      if (!exists) {
        return res.status(404).json({
          error: `Journey not found: ${journeyId}`,
          category,
          path: filePath,
        });
      }

      const [content] = await file.download();
      const json = JSON.parse(content.toString());

      res.set('Cache-Control', 'public, max-age=300'); // 5 min cache
      return res.status(200).json(json);
    } catch (error) {
      console.error('Error fetching journey:', error);
      return res.status(500).json({
        error: 'Failed to fetch journey',
        details: error.message,
      });
    }
  })();
});

/**
 * Lists all journey files in a category from Storage
 * 
 * Endpoint: GET /listJourneys?category={category}
 */
exports.listJourneys = functions.https.onRequest((req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  (async () => {
    try {
      const { category } = req.query;

      if (!category) {
        return res.status(400).json({
          error: 'Missing category parameter',
          example: '?category=married',
        });
      }

      const prefix = `journeys/${category}/`;
      const bucket = admin.storage().bucket();
      const [files] = await bucket.getFiles({ prefix });

      const journeys = files
        .map(f => f.name.replace(prefix, '').replace('.json', ''))
        .filter(id => id && !id.includes('/'));

      res.set('Cache-Control', 'public, max-age=300');
      return res.status(200).json({
        category,
        count: journeys.length,
        journeys,
      });
    } catch (error) {
      console.error('Error listing journeys:', error);
      return res.status(500).json({
        error: 'Failed to list journeys',
        details: error.message,
      });
    }
  })();
});
