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
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const crypto = require('crypto');

admin.initializeApp();

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
// PUSH NOTIFICATION FUNCTIONS
// ============================================================================

/**
 * Send FCM notification when notification document is created
 * Triggers on: users/{userId}/notifications/{notificationId}
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
      
      if (!userData || !userData.fcmToken || !userData.fcmToken.token) {
        console.log(`No FCM token found for user: ${userId}`);
        return null;
      }

      const fcmToken = userData.fcmToken.token;
      const payload = notification.payload;

      // Build FCM message
      const message = {
        token: fcmToken,
        notification: {
          title: payload.title || 'Nexus',
          body: payload.body || '',
        },
        data: {
          type: payload.type,
          route: payload.route || '/',
          notificationId: notificationId,
          ...Object.fromEntries(
            Object.entries(payload.data || {}).map(([key, value]) => [key, String(value)])
          ),
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'nexus_default_channel',
          },
        },
      };

      // Send notification via FCM
      const response = await admin.messaging().send(message);
      console.log(`✅ Push notification sent successfully: ${response}`);

      // Mark notification as sent
      await snapshot.ref.update({ isSent: true });

      return response;
    } catch (error) {
      console.error('❌ Error sending push notification:', error);
      
      // Mark notification as failed
      await snapshot.ref.update({
        isSent: false,
        error: error.message,
      });

      return null;
    }
  });

/**
 * Send notification when new chat message is received
 * Triggers on: chats/{chatId}/messages/{messageId}
 */
exports.onNewChatMessage = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const { chatId } = context.params;
    const message = snapshot.data();
    const senderId = message.senderId;
    const messageText = message.text || 'Sent a message';

    try {
      // Get chat participants
      const chatDoc = await admin.firestore().collection('chats').doc(chatId).get();
      const chatData = chatDoc.data();
      
      if (!chatData || !chatData.participants) {
        console.log(`Chat not found: ${chatId}`);
        return null;
      }

      const participants = chatData.participants;
      const recipientId = participants.find((id) => id !== senderId);

      if (!recipientId) {
        console.log('No recipient found');
        return null;
      }

      // Get sender's name
      const senderDoc = await admin.firestore().collection('users').doc(senderId).get();
      const senderName = senderDoc.data()?.firstName || 'Someone';

      // Create notification payload
      const notificationRef = admin
        .firestore()
        .collection('users')
        .doc(recipientId)
        .collection('notifications')
        .doc();

      const notification = {
        id: notificationRef.id,
        userId: recipientId,
        payload: {
          type: 'chat_message',
          title: `Message from ${senderName}`,
          body: messageText.length > 50 ? `${messageText.substring(0, 50)}...` : messageText,
          route: `/chats/${chatId}`,
          data: {
            chatId: chatId,
            senderId: senderId,
            senderName: senderName,
          },
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        isSent: false,
      };

      await notificationRef.set(notification);
      console.log(`✅ Chat notification queued for user: ${recipientId}`);

      return null;
    } catch (error) {
      console.error('❌ Error creating chat notification:', error);
      return null;
    }
  });

/**
 * Send notification when user profile is verified by admin
 * Triggers on: users/{userId} (when moderationStatus changes to verified)
 */
exports.onProfileVerified = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const { userId } = context.params;
    const before = change.before.data();
    const after = change.after.data();

    // Check if moderationStatus changed from pending to verified
    if (
      before.moderationStatus === 'pending' &&
      after.moderationStatus === 'verified'
    ) {
      try {
        // Create notification payload
        const notificationRef = admin
          .firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc();

        const notification = {
          id: notificationRef.id,
          userId: userId,
          payload: {
            type: 'profile_verified',
            title: 'Profile Verified! ✓',
            body: 'Your profile has been verified and is now visible to other users in the dating section.',
            route: '/dating',
            data: {},
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          isSent: false,
        };

        await notificationRef.set(notification);
        console.log(`✅ Profile verified notification queued for user: ${userId}`);

        return null;
      } catch (error) {
        console.error('❌ Error creating profile verified notification:', error);
        return null;
      }
    }

    return null;
  });

/**
 * Send notification for subscription expiring (runs daily)
 * Checks for subscriptions expiring in 3 days
 */
exports.checkExpiringSubscriptions = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const now = new Date();

    try {
      // Query users with subscriptions expiring in 3 days
      const usersSnapshot = await admin
        .firestore()
        .collection('users')
        .where('subscription.isActive', '==', true)
        .get();

      const notifications = [];

      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        const subscription = userData.subscription;

        if (!subscription || !subscription.expiryDate) continue;

        const expiryDate = subscription.expiryDate.toDate();
        const daysLeft = Math.ceil((expiryDate - now) / (1000 * 60 * 60 * 24));

        // Send notification if expiring in exactly 3 days
        if (daysLeft === 3 && subscription.autoRenew === false) {
          const notificationRef = admin
            .firestore()
            .collection('users')
            .doc(userDoc.id)
            .collection('notifications')
            .doc();

          const notification = {
            id: notificationRef.id,
            userId: userDoc.id,
            payload: {
              type: 'subscription_expiring',
              title: 'Subscription Expiring Soon',
              body: `Your premium subscription expires in ${daysLeft} days. Renew to keep your benefits!`,
              route: '/subscription',
              data: { daysLeft: daysLeft.toString() },
            },
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false,
            isSent: false,
          };

          notifications.push(notificationRef.set(notification));
        }
      }

      await Promise.all(notifications);
      console.log(`✅ Checked subscriptions, sent ${notifications.length} expiry notifications`);

      return null;
    } catch (error) {
      console.error('❌ Error checking expiring subscriptions:', error);
      return null;
    }
  });

// ============================================================================
// DO SPACES PRESIGNED URL FUNCTION
// ============================================================================

/**
 * POST /getPresignedUploadUrl
 * Headers: Authorization: Bearer <Firebase ID token>
 * Body: { type: "photo" | "audio", contentType: string }
 * Response: { uploadUrl, publicUrl, objectKey }
 */
exports.getPresignedUploadUrl = functions.https.onRequest(async (req, res) => {
  try {
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).send('Missing auth token');
      return;
    }

    const token = authHeader.slice('Bearer '.length);
    const decoded = await admin.auth().verifyIdToken(token);
    const uid = decoded.uid;

    const body = req.body || {};
    const type = body.type;
    const contentType = body.contentType;

    if (type !== 'photo' && type !== 'audio') {
      res.status(400).send("Invalid type. Use 'photo' or 'audio'.");
      return;
    }

    if (!contentType || typeof contentType !== 'string') {
      res.status(400).send('Missing contentType.');
      return;
    }

    // Read from environment (via runtime config or env vars)
    const SPACES_KEY = process.env.SPACES_KEY || functions.config().spaces?.key;
    const SPACES_SECRET = process.env.SPACES_SECRET || functions.config().spaces?.secret;
    const SPACES_ENDPOINT = process.env.SPACES_ENDPOINT || functions.config().spaces?.endpoint;
    const SPACES_BUCKET = process.env.SPACES_BUCKET || functions.config().spaces?.bucket;
    const SPACES_REGION = process.env.SPACES_REGION || functions.config().spaces?.region;

    if (!SPACES_KEY || !SPACES_SECRET || !SPACES_ENDPOINT || !SPACES_BUCKET || !SPACES_REGION) {
      console.error('Missing Spaces config:', {
        key: !!SPACES_KEY,
        secret: !!SPACES_SECRET,
        endpoint: !!SPACES_ENDPOINT,
        bucket: !!SPACES_BUCKET,
        region: !!SPACES_REGION,
      });
      res.status(500).send('Missing Spaces configuration');
      return;
    }

    const ext = type === 'photo'
      ? (contentType.includes('png') ? 'png' : 'jpg')
      : (contentType.includes('mpeg') ? 'mp3' : 'm4a');

    const rand = crypto.randomBytes(8).toString('hex');
    const objectKey = `users/${uid}/${type}s/${type}_${Date.now()}_${rand}.${ext}`;

    const client = new S3Client({
      region: SPACES_REGION,
      endpoint: SPACES_ENDPOINT,
      // DigitalOcean Spaces does not support the newer AWS flexible checksum
      // params (e.g., x-amz-sdk-checksum-algorithm) that the JS SDK may add by
      // default. Disable request checksums to avoid connection resets.
      requestChecksumCalculation: 'NEVER',
      credentials: {
        accessKeyId: SPACES_KEY,
        secretAccessKey: SPACES_SECRET,
      },
    });


    const cmd = new PutObjectCommand({
      Bucket: SPACES_BUCKET,
      Key: objectKey,
      ContentType: contentType,
      ACL: 'public-read',
    });
    const uploadUrl = await getSignedUrl(client, cmd, { expiresIn: 300 });

    // Stable public URL
    const ep = SPACES_ENDPOINT.replace(/\/$/, '');
    const publicUrl = `${ep}/${SPACES_BUCKET}/${objectKey}`;

    console.log('[getPresignedUploadUrl] Generated presigned URL', { 
      uid, 
      type, 
      objectKey,
      uploadUrl: uploadUrl.substring(0, 200) + '...',
      publicUrl,
    });
    res.json({ uploadUrl, publicUrl, objectKey });
  } catch (e) {
    console.error('[getPresignedUploadUrl] Error:', e);
    res.status(500).send('Failed to generate upload URL');
  }
});
