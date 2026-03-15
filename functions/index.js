/**
 * NEXUS 2.0 - CONSOLIDATED CLOUD FUNCTIONS (v5 API, Node 22)
 * 
 * Merged from firebase_functions/ and functions/ directories
 * Single source of truth for all Cloud Functions
 * 
 * Features:
 * - Push notifications via Firebase Cloud Messaging
 * - Email sending via Nodemailer
 * - File uploads to Digital Ocean Spaces
 * - Chat message notifications
 * - Weekly reporting
 * - And more...
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const { Parser } = require('json2csv');
const { S3Client, PutObjectCommand, PutObjectAclCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const crypto = require('crypto');

// ============================================================================
// INITIALIZATION (ONE ONLY - DO NOT DUPLICATE)
// ============================================================================

admin.initializeApp({
  storageBucket: 'nexus-visibility-app.appspot.com'
});

// Re-export scheduled Cloud Function for daily limit reset
const { resetDailyLimits } = require('./reset_daily_limits');
exports.resetDailyLimits = resetDailyLimits;

// Re-export purchase validation functions
const { validateAndRecordPurchase, validateAndRecordSubscription, revenueCatWebhook } = require('./validate_purchase');
exports.validateAndRecordPurchase = validateAndRecordPurchase;
exports.validateAndRecordSubscription = validateAndRecordSubscription;
exports.revenueCatWebhook = revenueCatWebhook;

// ============================================================================
// ADMIN VERIFICATION FUNCTION - Manually verify users by email
// ============================================================================

/**
 * HTTP Cloud Function: Verify a user's dating profile manually
 * 
 * USAGE:
 * POST /verifyUserProfile
 * Headers: Authorization: Bearer <YOUR_ID_TOKEN>
 * Body: {
 *   "email": "user@example.com",
 *   "verificationStatus": "verified" (optional, defaults to "verified")
 * }
 * 
 * RESPONSE:
 * {
 *   "success": true,
 *   "userId": "abc123",
 *   "message": "User verified: user@example.com",
 *   "updated": {
 *     "verificationStatus": "verified",
 *     "verifiedAt": "2026-03-13T10:30:00Z",
 *     "verifiedBy": "admin_manual_verification"
 *   }
 * }
 * 
 * SECURITY:
 * - Requires valid Firebase ID token
 * - Requires user to have admin: true custom claim
 * - Logs all changes for audit trail
 */
exports.verifyUserProfile = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') return res.status(200).send('');

  try {
    // 1. Verify authentication
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing or invalid Authorization header' });
    }

    const idToken = authHeader.substring(7);
    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (e) {
      return res.status(401).json({ error: 'Invalid ID token', details: e.message });
    }

    // 2. Check if user is admin
    if (!decodedToken.admin) {
      console.warn(`[verifyUserProfile] Non-admin user ${decodedToken.uid} tried to verify user`);
      return res.status(403).json({ 
        error: 'Admin access required',
        note: 'Your Firebase account needs admin: true custom claim'
      });
    }

    // 3. Extract email from request
    const { email, verificationStatus = 'verified' } = req.body;
    if (!email || typeof email !== 'string') {
      return res.status(400).json({ error: 'email field is required and must be a string' });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // 4. Find user by email
    console.log(`[verifyUserProfile] Admin ${decodedToken.uid} searching for user: ${normalizedEmail}`);
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('email', '==', normalizedEmail)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.warn(`[verifyUserProfile] User not found: ${normalizedEmail}`);
      return res.status(404).json({ error: `User not found with email: ${normalizedEmail}` });
    }

    const targetDoc = usersSnapshot.docs[0];
    const userId = targetDoc.id;
    const userData = targetDoc.data();

    // 5. Update verification status
    const now = admin.firestore.FieldValue.serverTimestamp();
    const updateData = {
      'dating.verificationStatus': verificationStatus,
      'dating.verifiedAt': now,
      'dating.verifiedBy': `admin:${decodedToken.uid}`,
      'dating.reviewedAt': now,
      'dating.reviewedBy': decodedToken.email || decodedToken.uid,
    };

    // Auto-lock verified users to prevent auto-revert on profile updates
    if (verificationStatus === 'verified') {
      updateData['dating.verificationLockedByAdmin'] = true;
      updateData['dating.verificationLockedAt'] = now;
      updateData['dating.verificationLockedReason'] = 'Auto-locked to prevent revert on profile updates';
      console.log(`[verifyUserProfile] ✅ Auto-locking user to prevent revert on profile edits`);
    }

    console.log(`[verifyUserProfile] Updating user ${userId}:`, updateData);
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update(updateData);

    // 5.1 Send notification based on verification status
    console.log(`[verifyUserProfile] Creating notification for status: ${verificationStatus}`);
    let notificationPayload = {
      createdAt: now,
      isSent: false,
    };

    if (verificationStatus === 'verified') {
      notificationPayload = {
        ...notificationPayload,
        type: 'profile_verified',
        title: '✅ Profile Verified!',
        body: 'Congratulations! Your profile has been verified.',
        payload: {
          type: 'profile_verified',
          title: '✅ Profile Verified!',
          body: 'Congratulations! Your profile has been verified.',
          route: '/search',
        },
      };
    } else if (verificationStatus === 'rejected') {
      notificationPayload = {
        ...notificationPayload,
        type: 'profile_rejected',
        title: '❌ Profile Rejected',
        body: 'Your profile was not approved. Check the app to see the reason.',
        payload: {
          type: 'profile_rejected',
          title: '❌ Profile Rejected',
          body: 'Your profile was not approved. Check the app to see the reason.',
          route: '/profile',
          verificationStatus: 'rejected',
        },
      };
    } else if (verificationStatus === 'pending') {
      notificationPayload = {
        ...notificationPayload,
        type: 'profile_pending_verification',
        title: '🔍 Profile Under Review',
        body: 'Your profile is being reviewed. You\'ll be notified of the decision soon.',
        payload: {
          type: 'profile_pending_verification',
          title: '🔍 Profile Under Review',
          body: 'Your profile is being reviewed. You\'ll be notified of the decision soon.',
          route: '/profile',
          verificationStatus: 'pending',
        },
      };
    }

    try {
      const notifRef = await admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add(notificationPayload);
      console.log(`[verifyUserProfile] ✅ Notification created for user ${userId}: ${notifRef.id}`);
    } catch (notifError) {
      console.warn(`[verifyUserProfile] ⚠️  Failed to create notification for user ${userId}: ${notifError.message}`);
      // Don't fail the entire function if notification creation fails
    }

    // 6. Log audit trail
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('auditLog')
      .add({
        action: 'dating_profile_verified_manually',
        performedBy: decodedToken.uid,
        performedByEmail: decodedToken.email,
        verificationStatus,
        timestamp: now,
      });

    console.log(`✅ [verifyUserProfile] Successfully verified ${normalizedEmail} (${userId})`);

    return res.status(200).json({
      success: true,
      userId,
      userEmail: userData.email,
      userName: userData.username || userData.name,
      message: `User verified: ${normalizedEmail}`,
      updated: {
        verificationStatus,
        verifiedAt: new Date().toISOString(),
        verifiedBy: `admin:${decodedToken.uid}`,
      },
    });

  } catch (error) {
    console.error('[verifyUserProfile] Error:', error);
    return res.status(500).json({
      success: false,
      error: error.message,
      code: error.code,
    });
  }
});

// ============================================================================
// EMAIL CONFIGURATION
// ============================================================================

/**
 * Gmail transporter - requires App Password
 * To set: firebase functions:config:set gmail.password="YOUR_APP_PASSWORD"
 */
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'nexusgodlydating@gmail.com',
    pass: functions.config().gmail?.password || process.env.GMAIL_APP_PASSWORD,
  },
});

// ============================================================================
// 1️⃣ SUPPORT REQUEST EMAIL FUNCTION
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
            <div style="background: linear-gradient(135deg, #BA223C 0%, #D64A60 100%); padding: 30px; border-radius: 16px 16px 0 0; text-align: center;">
              <h1 style="color: white; margin: 0; font-size: 28px; font-weight: 700;">📬 New Support Request</h1>
              <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 14px;">A user needs your help</p>
            </div>
            <div style="background: white; padding: 25px; border-left: 1px solid #e0e0e0; border-right: 1px solid #e0e0e0;">
              <h2 style="margin: 0 0 20px 0; font-size: 18px; color: #333;">📋 Request Details</h2>
              <table style="width: 100%; margin-bottom: 20px; border-collapse: collapse;">
                <tr style="border-bottom: 1px solid #f0f0f0;">
                  <td style="padding: 12px 0; font-weight: 600; width: 30%; color: #BA223C;">Category:</td>
                  <td style="padding: 12px 0; color: #666;">${data.category || 'N/A'}</td>
                </tr>
                <tr style="border-bottom: 1px solid #f0f0f0;">
                  <td style="padding: 12px 0; font-weight: 600; color: #BA223C;">Subject:</td>
                  <td style="padding: 12px 0; color: #666;">${data.subject || 'N/A'}</td>
                </tr>
                <tr style="border-bottom: 1px solid #f0f0f0;">
                  <td style="padding: 12px 0; font-weight: 600; color: #BA223C;">From:</td>
                  <td style="padding: 12px 0;"><a href="mailto:${data.userEmail}" style="color: #BA223C; text-decoration: none;">${data.userEmail || 'N/A'}</a></td>
                </tr>
                <tr>
                  <td style="padding: 12px 0; font-weight: 600; color: #BA223C;">Date:</td>
                  <td style="padding: 12px 0; color: #666;">${submittedDate}</td>
                </tr>
              </table>
              <h2 style="margin: 20px 0 12px 0; font-size: 18px; color: #333;">💬 Message</h2>
              <div style="background: #f9f9f9; padding: 15px; border-left: 4px solid #BA223C; border-radius: 4px; color: #666; line-height: 1.6;">
                ${data.message || 'No message provided'}
              </div>
            </div>
            <div style="background: #f5f5f5; padding: 20px; text-align: center; border-radius: 0 0 16px 16px; border-left: 1px solid #e0e0e0; border-right: 1px solid #e0e0e0; border-bottom: 1px solid #e0e0e0;">
              <p style="margin: 0; color: #999; font-size: 12px;">This is an automated message from Nexus Support System</p>
            </div>
          </div>
        </body>
        </html>
      `
    };
    
    try {
      await transporter.sendMail(mailOptions);
      console.log(`✅ Support email sent for request ${requestId}`);
      await snapshot.ref.update({
        emailSent: true,
        emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { success: true, requestId };
    } catch (error) {
      console.error(`❌ Error sending support email for ${requestId}:`, error);
      await snapshot.ref.update({
        emailSent: false,
        emailError: error.message,
      });
      return { success: false, error: error.message };
    }
  });

// ============================================================================
// 2️⃣ USER LIFECYCLE: WELCOME EMAIL
// ============================================================================

/**
 * Sends a welcome email when a new user signs up.
 */
exports.onUserCreated = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const userId = context.params.userId;
    
    if (!data.email) {
      console.log(`Skipping welcome email for ${userId} - no email`);
      return null;
    }
    
    const mailOptions = {
      from: '"Nexus Team" <nexusgodlydating@gmail.com>',
      to: data.email,
      subject: 'Welcome to Nexus! 🎉',
      html: `<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;"><div style="background: linear-gradient(135deg, #BA223C, #D64A60); padding: 40px 30px; border-radius: 16px 16px 0 0; text-align: center;"><h1 style="color: white; margin: 0; font-size: 32px;">Welcome to Nexus!</h1></div><div style="background: white; padding: 30px; border: 1px solid #e0e0e0;"><p style="font-size: 16px; color: #333; line-height: 1.6;">Hi ${data.fullName || data.username || 'there'}! 👋</p><p style="font-size: 16px; color: #333; line-height: 1.6;">We're thrilled to have you join the Nexus community.</p><ul style="font-size: 16px; color: #333; line-height: 1.8;"><li>Complete your profile to get better matches</li><li>Take the compatibility quiz</li><li>Explore our journey packages</li></ul></div><div style="background: #f5f5f5; padding: 20px; text-align: center; border-radius: 0 0 16px 16px;"><p style="margin: 0; color: #666; font-size: 12px;">© ${new Date().getFullYear()} Nexus</p></div></div>`
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
// 3️⃣ USER LIFECYCLE: ACCOUNT DELETION
// ============================================================================

/**
 * Automatically deletes the Firebase Auth user when their Firestore document is deleted.
 */
exports.onUserDeleted = functions.firestore
  .document('users/{userId}')
  .onDelete(async (snapshot, context) => {
    const userId = context.params.userId;
    const userData = snapshot.data();
    
    console.log(`🗑️  User document deleted: ${userId}`);
    
    try {
      await admin.auth().deleteUser(userId);
      console.log(`✅ Firebase Auth user deleted: ${userId}`);
      
      if (userData?.email) {
        try {
          await transporter.sendMail({
            from: '"Nexus Team" <nexusgodlydating@gmail.com>',
            to: userData.email,
            subject: 'Account Deletion Confirmation',
            html: `<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;"><div style="background: #f5f5f5; padding: 30px; border-radius: 16px;"><h2 style="color: #333;">Account Deleted</h2><p>Your Nexus account has been successfully deleted. All your data has been removed.</p></div></div>`
          });
        } catch (emailError) {
          console.error(`⚠️  Failed to send deletion email:`, emailError.message);
        }
      }
      
      return { success: true, userId };
    } catch (error) {
      console.error(`❌ Error deleting Auth user:`, error);
      if (error.code === 'auth/user-not-found') {
        return { success: true, userId, note: 'Already deleted' };
      }
      return { success: false, userId, error: error.message };
    }
  });

// ============================================================================
// 4️⃣ PUSH NOTIFICATIONS: FCM SERVICE (CRITICAL)
// ============================================================================

/**
 * Send FCM push notification when notification document is created
 * This is the MAIN trigger that sends all push notifications via Firebase Cloud Messaging.
 * 
 * ✅ UPDATED: Simplified token handling - app now always provides string token
 * ✅ UPDATED: Added token validation and logging
 */
exports.sendPushNotification = functions.firestore
  .document('users/{userId}/notifications/{notificationId}')
  .onCreate(async (snapshot, context) => {
    const { userId, notificationId } = context.params;
    const notification = snapshot.data();

    try {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      const userData = userDoc.data();
      
      // Validate user exists and has token
      if (!userData) {
        console.log(`⚠️ User document not found: ${userId}`);
        await admin.firestore()
          .collection('users').doc(userId).collection('notifications').doc(notificationId)
          .update({ 
            isSent: true, 
            sentAt: admin.firestore.FieldValue.serverTimestamp(), 
            sendError: 'User document not found' 
          });
        return null;
      }

      // ✅ IMPROVED: Expect fcmToken to always be a string (no object fallback)
      const fcmToken = userData.fcmToken;
      
      if (!fcmToken || typeof fcmToken !== 'string') {
        console.log(`⚠️ Invalid or missing FCM token for user: ${userId} (token type: ${typeof userData.fcmToken})`);
        await admin.firestore()
          .collection('users').doc(userId).collection('notifications').doc(notificationId)
          .update({ 
            isSent: true, 
            sentAt: admin.firestore.FieldValue.serverTimestamp(), 
            sendError: 'Invalid FCM token' 
          });
        return null;
      }

      // ✅ IMPROVED: Validate token format (FCM tokens typically 152+ chars)
      if (fcmToken.length < 50) {
        console.log(`⚠️ Token format invalid for user ${userId}: too short (${fcmToken.length} chars)`);
        await admin.firestore()
          .collection('users').doc(userId).collection('notifications').doc(notificationId)
          .update({ 
            isSent: true, 
            sentAt: admin.firestore.FieldValue.serverTimestamp(), 
            sendError: 'Token format invalid' 
          });
        return null;
      }

      // ✅ IMPROVED: Validate token is marked as valid by the app
      if (userData.fcmTokenValid !== true) {
        console.log(`⚠️ FCM token not marked as valid for user: ${userId}`);
        // Still try to send - might work
      }

      const payload = notification.payload || {};
      const notificationType = payload.type || notification.type || 'system';
      const isHighPriority = ['profile_pending_verification', 'profile_rejected', 'profile_verified', 'subscription_activated', 'chat_message'].includes(notificationType);

      // ✅ ROBUST: Check both nested payload and top-level fields for title/body
      const notifTitle = payload.title || notification.title || 'Nexus';
      const notifBody = payload.body || notification.body || '';

      const message = {
        token: fcmToken,
        notification: { 
          title: notifTitle, 
          body: notifBody 
        },
        android: {
          priority: isHighPriority ? 'high' : 'normal',
          notification: { 
            clickAction: 'FLUTTER_NOTIFICATION_CLICK', 
            sound: 'default', 
            channelId: 'nexus_default_channel', 
            icon: '@mipmap/ic_launcher',
            defaultVibrateTimings: true,
            notificationCount: 1
          }
        },
        apns: {
          headers: { 'apns-priority': isHighPriority ? '10' : '5' },
          payload: { 
            aps: { 
              alert: { 
                title: notifTitle, 
                body: notifBody 
              }, 
              badge: 1, 
              sound: 'default',
              'content-available': 1 // ✅ Critical for iOS notification delivery
            } 
          }
        },
      };

      if (payload && typeof payload === 'object') {
        message.data = {};
        for (const [key, value] of Object.entries(payload)) {
          if (['title', 'body', 'type'].includes(key)) continue;
          // Flatten nested objects (e.g. payload.data contains route, chatId, etc.)
          if (value && typeof value === 'object' && !Array.isArray(value)) {
            for (const [nestedKey, nestedValue] of Object.entries(value)) {
              message.data[nestedKey] = String(nestedValue);
            }
          } else {
            message.data[key] = String(value);
          }
        }
      }

      console.log(`📤 Sending FCM to ${userId} (platform: ${userData.fcmTokenPlatform || 'unknown'}): ${payload.title}`);
      const response = await admin.messaging().send(message);
      
      await admin.firestore()
        .collection('users').doc(userId).collection('notifications').doc(notificationId)
        .update({ 
          isSent: true, 
          sentAt: admin.firestore.FieldValue.serverTimestamp(), 
          fcmMessageId: response 
        });

      console.log(`✅ FCM sent successfully: messageId: ${response}`);
      return { success: true, messageId: response };

    } catch (error) {
      console.error(`❌ FCM error for ${userId}:`, error.message);
      try {
        await admin.firestore()
          .collection('users').doc(userId).collection('notifications').doc(notificationId)
          .update({ 
            isSent: false, 
            sendError: error.message, 
            lastAttemptAt: admin.firestore.FieldValue.serverTimestamp() 
          });
      } catch (e) {}
      return null;
    }
  });

// ============================================================================
// 5️⃣ PUSH NOTIFICATIONS: TEST FCM
// ============================================================================

/**
 * CALLABLE - Test FCM to a specific user
 */
exports.testSendNotification = functions.https.onCall(async (data, context) => {
  const { userId, title = 'Test', body = 'Test notification', type = 'test' } = data;

  if (!userId) throw new functions.https.HttpsError('invalid-argument', 'userId required');

  try {
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (!userData || !userData.fcmToken) {
      throw new functions.https.HttpsError('not-found', `No FCM token for ${userId}`);
    }

    const fcmToken = userData.fcmToken;
    if (!fcmToken || typeof fcmToken !== 'string') {
      throw new functions.https.HttpsError('failed-precondition', `Invalid or empty token for ${userId} (type: ${typeof userData.fcmToken})`);
    }

    const message = {
      token: fcmToken,
      notification: { title, body },
      android: { priority: 'high', notification: { clickAction: 'FLUTTER_NOTIFICATION_CLICK', sound: 'default', channelId: 'nexus_default_channel' } },
      apns: { headers: { 'apns-priority': '10' }, payload: { aps: { alert: { title, body }, badge: 1, sound: 'default' } } },
      data: { type, timestamp: new Date().toISOString() },
    };

    const response = await admin.messaging().send(message);
    return { success: true, messageId: response, message: `✅ Test sent to ${userId}` };

  } catch (error) {
    console.error(`❌ Test FCM error:`, error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});



// ============================================================================
// 7️⃣ CHAT MESSAGES: NEW MESSAGE NOTIFICATIONS
// ============================================================================

/**
 * Triggered when a new chat message is created
 * Sends notification to all participants except sender
 */
exports.onNewChatMessage = functions.firestore
  .document('nexus2_chats/{chatId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const startTime = Date.now();
    try {
      const message = snapshot.data();
      const { chatId } = context.params;

      // ✅ FIXED: Check for 'content' (not 'text') - matches Dart ChatMessage model
      if (!message || !message.senderId || !message.content) {
        console.warn(`⚠️  Invalid message in chat ${chatId}`);
        return { success: false, error: 'Missing fields' };
      }

      const senderId = message.senderId;
      const messageText = message.content; // ✅ FIXED: Use 'content' field

      const db = admin.firestore();

      // ✅ Fetch sender's display name from their user document
      let senderDisplayName = 'Someone';
      try {
        const senderDoc = await db.collection('users').doc(senderId).get();
        if (senderDoc.exists) {
          const senderData = senderDoc.data();
          const rawName = senderData.username || senderData.displayName || senderData.name || senderData.fullName || '';
          if (rawName.trim()) {
            // Title-capitalize: first letter of each word uppercase, rest lowercase
            senderDisplayName = rawName.trim()
              .split(/\s+/)
              .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
              .join(' ');
          }
        }
      } catch (nameErr) {
        console.warn(`⚠️  Could not fetch sender name for ${senderId}:`, nameErr.message);
      }

      const chatDoc = await db.collection('nexus2_chats').doc(chatId).get();

      if (!chatDoc.exists) {
        console.error(`❌ Chat not found: ${chatId}`);
        return { success: false, error: 'Chat not found', duration: Date.now() - startTime };
      }

      const chatData = chatDoc.data();
      // ✅ FIXED: Check for 'participantIds' first (v2), then 'participants' (legacy)
      const participants = chatData?.participantIds || chatData?.participants || [];

      if (participants.length === 0) {
        return { success: false, error: 'No participants', duration: Date.now() - startTime };
      }

      const notificationBody = `${senderDisplayName} sent you a message 😍😍`;
      const notificationPromises = [];
      let notificationCount = 0;

      for (const recipientId of participants) {
        if (recipientId === senderId) continue;

        // ✅ FIXED: Structure matches what sendPushNotification reads from payload.*
        const notificationDoc = {
          userId: recipientId,
          payload: {
            type: 'chat_message',
            title: 'Nexus',
            body: notificationBody,
            chatId,
            senderId,
            senderName: senderDisplayName,
            messagePreview: messageText.substring(0, 200),
            route: `/chats/${chatId}`,
            deepLink: `nexus://chat/${chatId}`,
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          isSent: false,
        };

        notificationPromises.push(
          db.collection('users').doc(recipientId).collection('notifications').add(notificationDoc)
            .then(docRef => {
              console.log(`✅ Notification for ${recipientId}: ${docRef.id}`);
              return { success: true, recipientId, notificationId: docRef.id };
            })
            .catch(error => {
              console.error(`❌ Failed for ${recipientId}:`, error);
              return { success: false, recipientId, error: error.message };
            })
        );
        notificationCount++;
      }

      if (notificationCount === 0) {
        return { success: true, chatId, notificationsCreated: 0, duration: Date.now() - startTime };
      }

      const results = await Promise.all(notificationPromises);
      const successCount = results.filter(r => r.success).length;

      console.log(`📬 Chat ${chatId}: ${successCount}/${notificationCount} created (${Date.now() - startTime}ms)`);
      return { success: true, chatId, notificationsCreated: successCount, totalRecipients: notificationCount, duration: Date.now() - startTime };

    } catch (error) {
      console.error(`❌ Chat message error:`, error);
      return { success: false, error: error.message, duration: Date.now() - startTime };
    }
  });

// ============================================================================
// 8️⃣ COACH APPLICATIONS: EMAIL TO ADMIN
// ============================================================================

/**
 * Triggered when a new coach application is submitted
 */
exports.onCoachApplicationSubmitted = functions.firestore
  .document('coachApplications/{applicationId}')
  .onCreate(async (snapshot, context) => {
    try {
      const data = snapshot.data();
      const applicationId = context.params.applicationId;
      const userId = data.userId;
      const bucket = admin.storage().bucket();

      console.log(`📝 Processing coach application: ${applicationId}`);

      let attachments = [];

      if (data.profilePhoto?.url) {
        try {
          const [files] = await bucket.getFiles({ prefix: `coaches/${userId}/profile_photo_` });
          if (files.length > 0) {
            const photoFile = files.sort((a, b) => b.name.localeCompare(a.name))[0];
            const content = await photoFile.download();
            attachments.push({
              filename: 'profile-photo.jpg',
              content: content[0],
              contentType: 'image/jpeg',
            });
          }
        } catch (err) {
          console.warn('⚠️  Could not download profile photo:', err.message);
        }
      }

      if (data.credentialsPdf?.url) {
        try {
          const [files] = await bucket.getFiles({ prefix: `coaches/${userId}/credentials_` });
          if (files.length > 0) {
            const pdfFile = files.sort((a, b) => b.name.localeCompare(a.name))[0];
            const content = await pdfFile.download();
            attachments.push({
              filename: 'credentials.pdf',
              content: content[0],
              contentType: 'application/pdf',
            });
          }
        } catch (err) {
          console.warn('⚠️  Could not download credentials:', err.message);
        }
      }

      const mailOptions = {
        from: 'nexusgodlydating@gmail.com',
        to: 'contact@nexus4singles.com',
        subject: `🎯 New Coach Application: ${data.fullName}`,
        html: `<div style="max-width: 600px; margin: 0 auto;"><div style="background: #667eea; color: white; padding: 24px; border-radius: 8px 8px 0 0; text-align: center;"><h1 style="margin: 0;">🎯 New Coach Application</h1></div><div style="background: #f9fafb; padding: 24px; border-radius: 0 0 8px 8px;"><table style="width: 100%;"><tr><td style="padding: 8px 0; font-weight: 600;">Name:</td><td>${data.fullName || 'N/A'}</td></tr><tr><td style="padding: 8px 0; font-weight: 600;">Email:</td><td><a href="mailto:${data.email}">${data.email || 'N/A'}</a></td></tr><tr><td style="padding: 8px 0; font-weight: 600;">Experience:</td><td>${data.yearsOfExperience || 0} years</td></tr></table></div></div>`,
        attachments,
      };

      await transporter.sendMail(mailOptions);
      console.log(`✅ Application email sent`);

      await snapshot.ref.update({
        emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending',
      });

      return { success: true, applicationId };

    } catch (error) {
      console.error('❌ Coach application error:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });

// ============================================================================
// 9️⃣ ADMIN: POLL AGGREGATE RECALCULATION
// ============================================================================

/**
 * Recalculates poll aggregate from individual votes
 */
exports.recalculatePollAggregate = functions.https.onCall(async (data, context) => {
  const { pollId } = data;
  if (!pollId) throw new functions.https.HttpsError('invalid-argument', 'pollId required');

  try {
    const db = admin.firestore();
    const votesSnapshot = await db.collection('pollVotes').doc(pollId).collection('votes').get();

    console.log(`Found ${votesSnapshot.size} votes for poll ${pollId}`);

    const optionCounts = {};
    votesSnapshot.forEach(doc => {
      const vote = doc.data();
      const optionId = vote.selectedOptionId;
      optionCounts[optionId] = (optionCounts[optionId] || 0) + 1;
    });

    const totalVotes = votesSnapshot.size;

    await db.collection('pollAggregates').doc(pollId).update({
      optionCounts,
      totalVotes,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Recalculated aggregate for ${pollId}`);
    return { success: true, pollId, optionCounts, totalVotes };

  } catch (error) {
    console.error(`❌ Poll recalc error:`, error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================================
// 🔟 JOURNEY CONTENT MANAGEMENT
// ============================================================================

/**
 * Fetches journey JSON files from cloud storage
 */
exports.getJourney = functions.https.onRequest((req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  (async () => {
    try {
      const { category, journeyId } = req.query;
      if (!category || !journeyId) {
        return res.status(400).json({ error: 'Missing parameters', required: ['category', 'journeyId'] });
      }

      const filePath = `journeys/${category}/${journeyId}.json`;
      const bucket = admin.storage().bucket();
      const file = bucket.file(filePath);
      const [exists] = await file.exists();

      if (!exists) return res.status(404).json({ error: `Journey not found: ${journeyId}` });

      const [content] = await file.download();
      res.set('Cache-Control', 'public, max-age=300');
      return res.status(200).json(JSON.parse(content.toString()));
    } catch (error) {
      console.error('Error fetching journey:', error);
      return res.status(500).json({ error: 'Failed to fetch journey' });
    }
  })();
});

/**
 * Lists all journey files in a category
 */
exports.listJourneys = functions.https.onRequest((req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  (async () => {
    try {
      const { category } = req.query;
      if (!category) return res.status(400).json({ error: 'Missing category' });

      const prefix = `journeys/${category}/`;
      const bucket = admin.storage().bucket();
      const [files] = await bucket.getFiles({ prefix });

      const journeys = files
        .map(f => f.name.replace(prefix, '').replace('.json', ''))
        .filter(id => id && !id.includes('/'));

      res.set('Cache-Control', 'public, max-age=300');
      return res.status(200).json({ category, count: journeys.length, journeys });
    } catch (error) {
      console.error('Error listing journeys:', error);
      return res.status(500).json({ error: 'Failed to list journeys' });
    }
  })();
});

// ============================================================================
// 1️⃣1️⃣ WEEKLY REPORTING
// ============================================================================

/**
 * Scheduled: Runs every Monday at 9 AM UTC
 * Generates CSV report of new users
 */
exports.weeklyUserReport = functions.pubsub
  .schedule('0 9 * * 1')
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      console.log('🚀 Starting weekly user report...');
      
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
      
      const snapshot = await admin.firestore()
        .collection('users')
        .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(sevenDaysAgo))
        .orderBy('createdAt', 'desc')
        .get();
      
      if (snapshot.empty) {
        console.log('ℹ️  No new users this week');
        return { success: true, message: 'No new users', usersCount: 0 };
      }
      
      const users = [];
      snapshot.forEach(doc => {
        const userData = doc.data();
        users.push({
          email: userData.email || 'N/A',
          username: userData.username || 'N/A',
          nationality: userData.dating?.profile?.nationality || 'N/A',
          region: userData.dating?.profile?.country || 'N/A',
          dateJoined: userData.createdAt ? userData.createdAt.toDate().toISOString().split('T')[0] : 'N/A',
        });
      });
      
      const parser = new Parser({ fields: ['email', 'username', 'nationality', 'region', 'dateJoined'] });
      const csv = parser.parse(users);
      
      const today = new Date().toISOString().split('T')[0];
      const filename = `user-reports/new-users-${today}.csv`;
      
      const bucket = admin.storage().bucket();
      await bucket.file(filename).save(csv, {
        metadata: { contentType: 'text/csv', cacheControl: 'public, max-age=3600' }
      });
      
      console.log(`✅ Report uploaded: ${filename}`);
      return { success: true, usersCount: users.length, filename };
      
    } catch (error) {
      console.error('❌ Report error:', error);
      throw error;
    }
  });

// ============================================================================
// 1️⃣2️⃣ DIGITAL OCEAN SPACES: FILE UPLOADS
// ============================================================================

/**
 * Generate presigned URL for uploading files to Digital Ocean Spaces
 */
exports.getPresignedUploadUrl = functions
  .runWith({ secrets: ['SPACES_SECRET'] })
  .https.onRequest(async (req, res) => {
  try {
    if (req.method !== 'POST') return res.status(405).send('Method not allowed');
    
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) return res.status(401).send('Unauthorized');
    const token = authHeader.slice(7);
    const decoded = await admin.auth().verifyIdToken(token);
    const uid = decoded.uid;

    const { type, contentType: clientContentType } = req.body || {};
    if (type !== 'photo' && type !== 'audio') return res.status(400).send('Invalid type');

    // Read config from process.env (populated by .env.nexus-visibility-app + Secret Manager)
    const rawEndpoint = process.env.SPACES_ENDPOINT || 'https://ams3.digitaloceanspaces.com';
    const bucket = process.env.SPACES_BUCKET || 'nexus-v2-users';
    const region = process.env.SPACES_REGION || 'ams3';
    const accessKey = process.env.SPACES_KEY || '';
    const secretKey = process.env.SPACES_SECRET || '';

    const hostname = rawEndpoint.replace(/^https?:\/\//, '').replace(/\/+$/, '');
    const cleanEndpoint = `https://${hostname}`;

    const client = new S3Client({
      region,
      endpoint: cleanEndpoint,
      forcePathStyle: true,
      credentials: {
        accessKeyId: accessKey,
        secretAccessKey: secretKey,
      },
    });

    // Use client-provided contentType if available, else default.
    // This fixes iOS→Android media bug where content type mismatches cause playback failures.
    let finalContentType = clientContentType || (type === 'photo' ? 'image/jpeg' : 'audio/mp4');
    
    // Map extension from content type (preserves client intent)
    let ext = 'jpg'; // default
    const ctLower = (finalContentType || '').toLowerCase();
    if (ctLower.includes('audio')) {
      ext = ctLower.includes('mp3') ? 'mp3' : ctLower.includes('wav') ? 'wav' : 'm4a';
    } else if (ctLower.includes('image')) {
      if (ctLower.includes('heic')) ext = 'heic';
      else if (ctLower.includes('png')) ext = 'png';
      else if (ctLower.includes('webp')) ext = 'webp';
      else ext = 'jpg'; // Fallback to JPEG
    }
    
    const objectKey = `users/${uid}/${type}s/${type}_${Date.now()}_${crypto.randomBytes(4).toString('hex')}.${ext}`;

    const cmd = new PutObjectCommand({
      Bucket: bucket,
      Key: objectKey,
      ContentType: finalContentType,
      ACL: 'public-read',
    });
    
    const uploadUrl = await getSignedUrl(client, cmd, { expiresIn: 300 });
    const publicUrl = `https://${hostname}/${bucket}/${objectKey}`;

    res.json({ uploadUrl, publicUrl, objectKey, contentType: finalContentType });
  } catch (e) {
    console.error('Presign error:', e);
    res.status(500).send('Internal Error');
  }
});

/// Set object ACL to public-read after upload completes.
/// Called by client after successfully uploading a file to the presigned URL.
/// This ensures the file is publicly accessible even if the presigned URL
/// didn't include ACL parameters (some S3-compatible services don't support this).
exports.setObjectAcl = functions
  .runWith({ secrets: ['SPACES_SECRET'] })
  .https.onRequest(async (req, res) => {
  try {
    if (req.method !== 'POST') return res.status(405).send('Method not allowed');
    
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) return res.status(401).send('Unauthorized');
    const token = authHeader.slice(7);
    const decoded = await admin.auth().verifyIdToken(token);
    const uid = decoded.uid;

    const { objectKey } = req.body || {};
    if (!objectKey || typeof objectKey !== 'string') {
      return res.status(400).send('objectKey required');
    }

    // Ensure the object belongs to the authenticated user (prevent ACL bypass)
    if (!objectKey.startsWith(`users/${uid}/`)) {
      return res.status(403).send('Forbidden: object does not belong to user');
    }

    const rawEndpoint = process.env.SPACES_ENDPOINT || 'https://ams3.digitaloceanspaces.com';
    const bucket = process.env.SPACES_BUCKET || 'nexus-v2-users';
    const region = process.env.SPACES_REGION || 'ams3';
    const accessKey = process.env.SPACES_KEY || '';
    const secretKey = process.env.SPACES_SECRET || '';

    const hostname = rawEndpoint.replace(/^https?:\/\//, '').replace(/\/+$/, '');
    const cleanEndpoint = `https://${hostname}`;

    const client = new S3Client({
      region,
      endpoint: cleanEndpoint,
      forcePathStyle: true,
      credentials: {
        accessKeyId: accessKey,
        secretAccessKey: secretKey,
      },
    });

    // Set the object ACL to public-read
    const aclCmd = new PutObjectAclCommand({
      Bucket: bucket,
      Key: objectKey,
      ACL: 'public-read',
    });

    await client.send(aclCmd);
    console.log(`[ACL] Set ${objectKey} to public-read`);

    res.json({ success: true, message: 'ACL set to public-read' });
  } catch (e) {
    console.error('Set ACL error:', e);
    res.status(500).json({ success: false, error: e.message });
  }
});

// ============================================================================
// FLUTTERWAVE WEBHOOK: Handle Subscription Activation
// ============================================================================

/**
 * Accepts Flutterwave payment webhooks and activates subscriptions
 * GEN 2 CLOUD FUNCTION
 * 
 * Webhook expects:
 * - POST request with signature verification via HMAC-SHA256
 * - Signature in: verificationhash or x-flutterwave-signature header
 * - Body contains: id, status, tx_ref (format: "nexus_sub:{userId}"), amount, currency
 * 
 * On success:
 * - Sets user.onPremium = true
 * - Sets user.subExpDate = 30 days from now
 * - Creates audit log entry
 * - Creates notification
 * 
 * Cloud Run URL: https://handleupdateusersubscriptionstatus-{hash}-{region}.a.run.app
 */
exports.handleUpdateUserSubscriptionStatus = functions
  .region('us-central1')
  .runWith({ 
    secrets: ['FLUTTERWAVE_WEBHOOK_SECRET'],
    memory: '256MB',
    timeoutSeconds: 60,
  })
  .https.onRequest(async (req, res) => {
    const WEBHOOK_SECRET = process.env.FLUTTERWAVE_WEBHOOK_SECRET;
    
    try {
      // Only accept POST requests
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

      // Validate request body exists
      if (!req.body) {
        console.error('[Flutterwave] Missing request body');
        return res.status(400).json({ error: 'Missing request body' });
      }

      console.log('[Flutterwave] Webhook received:', req.body?.data?.id);

      // ====================================================================
      // SECURITY: Verify webhook signature
      // ====================================================================
      const signature = req.headers['verificationhash'] || req.headers['x-flutterwave-signature'];
      if (!signature) {
        console.error('[Flutterwave] Missing signature header');
        return res.status(401).json({ error: 'Unauthorized: Missing signature' });
      }

      if (!WEBHOOK_SECRET) {
        console.error('[Flutterwave] Webhook secret not configured');
        return res.status(500).json({ error: 'Server misconfigured' });
      }

      // Flutterwave uses SHA256 hash for verification
      const payload = JSON.stringify(req.body);
      const hash = crypto
        .createHmac('sha256', WEBHOOK_SECRET)
        .update(payload)
        .digest('hex');

      if (hash !== signature) {
        console.error('[Flutterwave] Signature verification failed');
        return res.status(401).json({ error: 'Unauthorized: Invalid signature' });
      }

      console.log('[Flutterwave] ✓ Signature verified');

      // ====================================================================
      // Parse webhook data
      // ====================================================================
      const webhookData = req.body.data;
      if (!webhookData) {
        return res.status(400).json({ error: 'Missing webhook data' });
      }

      const {
        id: transactionId,
        status,
        tx_ref: txRef,
        amount,
        currency,
        customer: { email } = {},
        meta = {},
      } = webhookData;

      console.log(`[Flutterwave] Transaction ${transactionId}: status=${status}, ref=${txRef}`);

      // Only process successful payments
      if (status !== 'successful') {
        console.log(`[Flutterwave] Ignoring non-successful status: ${status}`);
        return res.status(200).json({ success: true, message: 'Payment not successful, ignored' });
      }

      if (!txRef) {
        console.error('[Flutterwave] Missing tx_ref - cannot identify user');
        return res.status(400).json({ error: 'Missing tx_ref' });
      }

      // Validate amount
      if (!amount || amount <= 0) {
        console.error(`[Flutterwave] Invalid amount: ${amount}`);
        return res.status(400).json({ error: 'Invalid payment amount' });
      }

      // ====================================================================
      // Extract userId from tx_ref
      // Format: "nexus_sub:{userId}"
      // ====================================================================
      if (!txRef.startsWith('nexus_sub:')) {
        console.error(`[Flutterwave] Invalid tx_ref format (must start with 'nexus_sub:'): ${txRef}`);
        return res.status(400).json({ error: 'Invalid tx_ref format - must be nexus_sub:{userId}' });
      }

      const userId = txRef.substring(9); // Remove "nexus_sub:" prefix

      if (!userId || userId.trim() === '') {
        console.error(`[Flutterwave] Empty userId in tx_ref: ${txRef}`);
        return res.status(400).json({ error: 'Empty userId in tx_ref' });
      }

      console.log(`[Flutterwave] Processing subscription for user: ${userId}`);

      // ====================================================================
      // Verify user exists
      // ====================================================================
      const userRef = admin.firestore().collection('users').doc(userId);
      const userDoc = await userRef.get();

      if (!userDoc.exists) {
        console.error(`[Flutterwave] User not found: ${userId}`);
        return res.status(404).json({ error: 'User not found' });
      }

      // ====================================================================
      // PREVENT DUPLICATE TRANSACTIONS
      // Check if this transaction was already processed
      // ====================================================================
      const existingLog = await userRef
        .collection('auditLog')
        .where('transactionId', '==', transactionId)
        .limit(1)
        .get();

      if (!existingLog.empty) {
        console.log(`[Flutterwave] Transaction already processed: ${transactionId}`);
        return res.status(200).json({ 
          success: true, 
          message: 'Transaction already processed',
          note: 'This webhook was sent before, ignoring duplicate'
        });
      }

      const userData = userDoc.data();
      console.log(`[Flutterwave] User found: ${userData?.email || userData?.username}`);

      // ====================================================================
      // Calculate subscription expiration (30 days from now)
      // ====================================================================
      const expiryDate = new Date();
      expiryDate.setDate(expiryDate.getDate() + 30);

      // ====================================================================
      // UPDATE USER SUBSCRIPTION FIELDS
      // ====================================================================
      const updateData = {
        // Subscription activation
        onPremium: true,
        subExpDate: admin.firestore.Timestamp.fromDate(expiryDate),
        entitledUser: true,
        
        // External payment tracking
        hasExternalSubscriptionFlow: true,
        lastFlutterwaveTransactionId: transactionId,
        
        // Payment history
        lastPaymentMethod: 'flutterwave',
        lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
        lastPaymentAmount: amount,
        lastPaymentCurrency: currency,
        
        // Mark as recurring customer
        prevSubscribed: true,
        
        // Timestamp
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await userRef.update(updateData);
      console.log(`[Flutterwave] ✓ Subscription activated for user ${userId}, expires ${expiryDate.toISOString()}`);

      // ====================================================================
      // CREATE AUDIT LOG
      // ====================================================================
      await userRef
        .collection('auditLog')
        .add({
          action: 'subscription_activated_external',
          provider: 'flutterwave',
          transactionId,
          amount,
          currency,
          expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          email,
        });

      console.log(`[Flutterwave] ✓ Audit log created for transaction ${transactionId}`);

      // ====================================================================
      // CREATE NOTIFICATION (isolated - don't fail webhook if this fails)
      // ====================================================================
      try {
        const notification = {
          type: 'subscription_activated_external',
          title: '💎 Premium Activated',
          body: `Your Nexus Premium subscription is now active for 30 days!`,
          payload: {
            type: 'subscription_activated_external',
            title: '💎 Premium Activated',
            body: `Your Nexus Premium subscription is now active for 30 days!`,
            route: '/subscription',
            expiryDate: expiryDate.toISOString(),
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isSent: false,
        };

        const notifRef = await userRef
          .collection('notifications')
          .add(notification);

        console.log(`[Flutterwave] ✓ Notification created: ${notifRef.id}`);
      } catch (notifError) {
        console.warn(`[Flutterwave] ⚠️ Failed to create notification for user ${userId}: ${notifError.message}`);
        // Don't fail webhook - subscription was already activated
      }

      // ====================================================================
      // SUCCESS RESPONSE
      // ====================================================================
      return res.status(200).json({
        success: true,
        message: 'Subscription activated successfully',
        userId,
        transactionId,
        expiryDate: expiryDate.toISOString(),
      });

    } catch (error) {
      console.error('[Flutterwave] Error:', error);
      return res.status(500).json({
        error: 'Internal server error',
        details: error.message,
      });
    }
  });

// ============================================================================
// SCHEDULED FUNCTION: Cancel Expired Subscriptions
// Runs daily at 2:00 AM UTC to check and cancel expired subscriptions
// ============================================================================

/**
 * Automatically cancels subscriptions that have passed their expiry date
 * GEN 2 CLOUD FUNCTION
 * 
 * Sets onPremium = false and creates audit log entry
 * Runs on a schedule (Cloud Scheduler trigger) - Daily at 2:00 AM UTC
 */
exports.checkAndCancelExpiredSubscriptions = functions
  .region('us-central1')
  .pubsub.schedule('0 2 * * *') // Daily at 2:00 AM UTC
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('[SubscriptionExpiry] Starting scheduled check for expired subscriptions');
    
    try {
      const db = admin.firestore();
      const now = admin.firestore.Timestamp.now();

      // Find all users with onPremium = true and subExpDate <= now
      // Paginate in batches to avoid timeout/memory issues
      const expiredSnapshot = await db
        .collection('users')
        .where('onPremium', '==', true)
        .where('subExpDate', '<=', now)
        .limit(1000) // Process max 1000 at a time
        .get();

      console.log(`[SubscriptionExpiry] Found ${expiredSnapshot.docs.length} expired subscriptions`);

      let processedCount = 0;
      let errorCount = 0;

      for (const userDoc of expiredSnapshot.docs) {
        try {
          const userId = userDoc.id;
          const userData = userDoc.data();
          const expiredDate = userData.subExpDate?.toDate();

          console.log(`[SubscriptionExpiry] Cancelling subscription for user ${userId} (expired: ${expiredDate})`);

          // Cancel subscription
          await userDoc.ref.update({
            onPremium: false,
            cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
            lastCancellationReason: 'subscription_expired',
          });

          // Create audit log
          await userDoc.ref
            .collection('auditLog')
            .add({
              action: 'subscription_expired_auto_cancelled',
              provider: 'flutterwave',
              expiryDate: userData.subExpDate,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              reason: 'Subscription expiration date reached',
            });

          // Create notification
          await userDoc.ref
            .collection('notifications')
            .add({
              type: 'subscription_expired',
              title: '⏰ Subscription Expired',
              body: 'Your Premium subscription has expired. Renew to maintain access to premium features.',
              payload: {
                type: 'subscription_expired',
                route: '/subscription',
              },
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              isSent: false,
            });

          console.log(`[SubscriptionExpiry] ✓ Cancelled for user ${userId}`);
          processedCount++;
        } catch (error) {
          console.error(`[SubscriptionExpiry] Error processing user ${userDoc.id}:`, error);
          errorCount++;
        }
      }

      console.log(`[SubscriptionExpiry] Complete: ${processedCount} cancelled, ${errorCount} errors`);
      return { processed: processedCount, errors: errorCount };

    } catch (error) {
      console.error('[SubscriptionExpiry] Fatal error:', error);
      throw error;
    }
  });
