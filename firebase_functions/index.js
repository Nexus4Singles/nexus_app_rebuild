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
