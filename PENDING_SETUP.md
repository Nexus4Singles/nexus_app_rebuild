# NEXUS 2.0 - PENDING SETUP ITEMS

This document tracks all setup tasks that need to be completed before launch.

---

## 📋 STATUS OVERVIEW

| Item | Status | Priority |
|------|--------|----------|
| Firebase Configuration | ⏳ Pending | **HIGH** |
| Firebase Crashlytics | ⏳ Pending | Medium |
| Cloud Function (Contact Support) | ⏳ Pending | Medium |
| RevenueCat Activation | ⏳ Pending | Before Launch |
| App Store Products | ⏳ Pending | Before Launch |
| Google Sign-In SHA Keys | ⏳ Pending | **HIGH** |

---

## 1. 🔥 FIREBASE CONFIGURATION

### Prerequisites
- Firebase CLI installed
- FlutterFire CLI installed
- Access to "Nexus App" Firebase project

### Package Name Decision Required

**Current options:**
- Test: `com.nexusapptest.app`
- Production: `com.nexus4singles.nexus`

**Decision:** [ ] Keep existing `com.nexus4singles.nexus` OR [ ] Use new package name: _______________

### Setup Steps

#### Step 1: Install Tools (one-time)
```bash
# Install Firebase CLI
npm install -g firebase-tools
# OR
curl -sL https://firebase.tools | bash

# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Add to PATH (add to ~/.bashrc or ~/.zshrc for permanent)
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

#### Step 2: Login to Firebase
```bash
firebase login
```

#### Step 3: Navigate to Project
```bash
cd /path/to/nexus_app
```

#### Step 4: Run FlutterFire Configure
```bash
flutterfire configure
```

**When prompted:**
1. Select project: `Nexus App`
2. Select platforms: `android`, `ios`
3. Android package name: `com.nexus4singles.nexus` (or your chosen name)
4. iOS bundle ID: `com.nexus4singles.nexus` (or your chosen name)

#### Step 5: Update main.dart
After `firebase_options.dart` is generated, edit `lib/main.dart`:

```dart
// Uncomment this import:
import 'firebase_options.dart';

// Uncomment Firebase initialization in main():
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

#### Step 6: Verify
```bash
flutter pub get
flutter run
```

### Verification Checklist
- [ ] `lib/firebase_options.dart` exists
- [ ] Import uncommented in `main.dart`
- [ ] `Firebase.initializeApp()` uncommented
- [ ] App runs without Firebase errors
- [ ] Can login/signup successfully

---

## 2. 📊 FIREBASE CRASHLYTICS

Crashlytics provides crash reporting and analytics for production.

### Setup Steps

#### Step 1: Add Crashlytics to Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select "Nexus App" project
3. Click "Crashlytics" in left sidebar
4. Enable Crashlytics for iOS and Android

#### Step 2: Add Dependencies
Add to `pubspec.yaml`:
```yaml
dependencies:
  firebase_crashlytics: ^3.4.8
```

#### Step 3: Update main.dart
```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  
  // Catch async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  runApp(const ProviderScope(child: NexusApp()));
}
```

#### Step 4: Update Error Handler Service
In `lib/core/services/error_handler_service.dart`, uncomment the Crashlytics line:

```dart
void logError(dynamic error, [StackTrace? stackTrace]) {
  debugPrint('ERROR: $error');
  
  // Send to Firebase Crashlytics in production
  FirebaseCrashlytics.instance.recordError(error, stackTrace);
}
```

#### Step 5: Test Crashlytics
```dart
// Add this temporarily to test (remove after confirming it works)
FirebaseCrashlytics.instance.crash();
```

### Verification Checklist
- [ ] Crashlytics enabled in Firebase Console
- [ ] `firebase_crashlytics` added to pubspec.yaml
- [ ] Crashlytics initialized in main.dart
- [ ] Error handler sends errors to Crashlytics
- [ ] Test crash appears in Firebase Console

---

## 3. 📧 CLOUD FUNCTION - CONTACT SUPPORT EMAIL

This Cloud Function automatically emails support requests to `nexusgodlydating@gmail.com`.

### Prerequisites
- Node.js 18+ installed
- Firebase CLI installed
- Firebase Blaze plan (required for outbound email)

### Setup Steps

#### Step 1: Initialize Cloud Functions
```bash
cd /path/to/nexus_app
firebase init functions
```

**When prompted:**
- Language: JavaScript or TypeScript
- ESLint: Yes
- Install dependencies: Yes

#### Step 2: Install Nodemailer
```bash
cd functions
npm install nodemailer
```

#### Step 3: Create the Function
Create/replace `functions/index.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Configure email transport
// Option A: Gmail (requires App Password)
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'nexusgodlydating@gmail.com',
    pass: process.env.GMAIL_APP_PASSWORD, // Set in Firebase config
  },
});

// Cloud Function: Send email when support request is created
exports.onSupportRequestCreated = functions.firestore
  .document('supportRequests/{requestId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const requestId = context.params.requestId;
    
    const mailOptions = {
      from: '"Nexus Support" <nexusgodlydating@gmail.com>',
      to: 'nexusgodlydating@gmail.com',
      replyTo: data.userEmail || 'noreply@nexus.com',
      subject: `[Nexus Support] ${data.category}: ${data.subject}`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: linear-gradient(135deg, #BA223C, #D64A60); padding: 20px; border-radius: 10px 10px 0 0;">
            <h1 style="color: white; margin: 0; font-size: 24px;">New Support Request</h1>
          </div>
          
          <div style="background: #f9f9f9; padding: 20px; border: 1px solid #e0e0e0;">
            <table style="width: 100%; border-collapse: collapse;">
              <tr>
                <td style="padding: 8px 0; color: #666; width: 120px;"><strong>Request ID:</strong></td>
                <td style="padding: 8px 0;">${requestId}</td>
              </tr>
              <tr>
                <td style="padding: 8px 0; color: #666;"><strong>Username:</strong></td>
                <td style="padding: 8px 0;">${data.username || 'N/A'}</td>
              </tr>
              <tr>
                <td style="padding: 8px 0; color: #666;"><strong>Email:</strong></td>
                <td style="padding: 8px 0;"><a href="mailto:${data.userEmail}">${data.userEmail || 'N/A'}</a></td>
              </tr>
              <tr>
                <td style="padding: 8px 0; color: #666;"><strong>User ID:</strong></td>
                <td style="padding: 8px 0; font-family: monospace; font-size: 12px;">${data.userId || 'N/A'}</td>
              </tr>
              <tr>
                <td style="padding: 8px 0; color: #666;"><strong>Category:</strong></td>
                <td style="padding: 8px 0;"><span style="background: #BA223C; color: white; padding: 4px 12px; border-radius: 20px; font-size: 12px;">${data.category}</span></td>
              </tr>
              <tr>
                <td style="padding: 8px 0; color: #666;"><strong>Platform:</strong></td>
                <td style="padding: 8px 0;">${data.platform || 'N/A'}</td>
              </tr>
              <tr>
                <td style="padding: 8px 0; color: #666;"><strong>App Version:</strong></td>
                <td style="padding: 8px 0;">${data.appVersion || 'N/A'}</td>
              </tr>
              <tr>
                <td style="padding: 8px 0; color: #666;"><strong>Submitted:</strong></td>
                <td style="padding: 8px 0;">${data.createdAt ? new Date(data.createdAt.toDate()).toLocaleString() : 'N/A'}</td>
              </tr>
            </table>
          </div>
          
          <div style="background: white; padding: 20px; border: 1px solid #e0e0e0; border-top: none;">
            <h3 style="color: #333; margin-top: 0;">Subject</h3>
            <p style="color: #333; font-size: 16px; font-weight: 500;">${data.subject}</p>
            
            <h3 style="color: #333;">Message</h3>
            <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; white-space: pre-wrap;">${data.message}</div>
          </div>
          
          <div style="background: #f0f0f0; padding: 15px; border-radius: 0 0 10px 10px; text-align: center; border: 1px solid #e0e0e0; border-top: none;">
            <p style="margin: 0; color: #666; font-size: 12px;">
              Reply directly to this email to respond to the user.
            </p>
          </div>
        </div>
      `,
    };
    
    try {
      await transporter.sendMail(mailOptions);
      console.log('Support email sent successfully for request:', requestId);
      
      // Update the request status
      await snapshot.ref.update({
        emailSent: true,
        emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return { success: true };
    } catch (error) {
      console.error('Error sending support email:', error);
      
      await snapshot.ref.update({
        emailSent: false,
        emailError: error.message,
      });
      
      return { success: false, error: error.message };
    }
  });
```

#### Step 4: Set Gmail App Password
1. Go to your Google Account → Security
2. Enable 2-Factor Authentication (if not already)
3. Go to App Passwords
4. Create new app password for "Mail"
5. Copy the 16-character password

```bash
firebase functions:config:set gmail.password="your-16-char-app-password"
```

#### Step 5: Deploy
```bash
firebase deploy --only functions
```

### Alternative: Use SendGrid (Recommended for Production)
If Gmail limits become an issue, use SendGrid:

```javascript
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

// Replace nodemailer.sendMail with:
await sgMail.send(mailOptions);
```

### Verification Checklist
- [ ] Firebase Blaze plan activated
- [ ] Cloud Functions initialized
- [ ] Gmail App Password created and configured
- [ ] Function deployed successfully
- [ ] Test support request triggers email
- [ ] Email received at nexusgodlydating@gmail.com

---

## 4. 💳 REVENUECAT ACTIVATION

RevenueCat is configured but disabled. Enable when ready for launch.

### Current Status
- ✅ API keys stored in `lib/core/services/revenuecat_service.dart`
- ✅ Apple Key: `appl_dfjYQwnRsUjojfOSnYGqciVcGzx`
- ✅ Google Key: `goog_mjvhTsGNNSzgnXyRVrIGjCmXwol`
- ⏳ `_isProductionReady = false` (purchases disabled)

### To Activate
1. Set up products in App Store Connect and Google Play Console
2. Configure products in RevenueCat dashboard
3. Change `_isProductionReady` to `true` in `revenuecat_service.dart`:

```dart
// Change this:
static const bool _isProductionReady = false;

// To this:
static const bool _isProductionReady = true;
```

### Verification Checklist
- [ ] Products created in App Store Connect
- [ ] Products created in Google Play Console
- [ ] Products configured in RevenueCat dashboard
- [ ] Entitlement "premium" created in RevenueCat
- [ ] `_isProductionReady` set to `true`
- [ ] Test purchase flow works

---

## 5. 🏪 APP STORE PRODUCTS SETUP

### Journey Package Product IDs
Use these IDs when creating products in the stores:

| Product ID | Name | Price (NGN) | Price (USD) | Price (GBP) |
|------------|------|-------------|-------------|-------------|
| `attraction_discernment` | Attraction & Discernment | ₦2,800 | $3.00 | £2.80 |
| `emotional_readiness_healing` | Emotional Readiness & Healing | ₦2,800 | $3.00 | £2.80 |
| `values_priorities_alignment` | Values & Priorities | ₦2,800 | $3.00 | £2.80 |
| `communication_connection` | Communication & Connection | ₦2,800 | $3.00 | £2.80 |
| `faith_and_purpose` | Faith & Purpose | ₦2,800 | $3.00 | £2.80 |
| `co_parenting_peace_plan` | Co-Parenting Peace Plan | ₦2,800 | $3.00 | £2.80 |
| `appreciation_friendship` | Appreciation & Friendship | ₦2,800 | $3.00 | £2.80 |
| `emotional_intimacy_closeness` | Emotional Intimacy | ₦2,800 | $3.00 | £2.80 |
| `conflict_repair` | Conflict & Repair | ₦2,800 | $3.00 | £2.80 |

### Premium Subscription Product IDs
| Product ID | Duration | Suggested Price |
|------------|----------|-----------------|
| `nexus_premium_monthly` | 1 Month | $9.99/month |
| `nexus_premium_quarterly` | 3 Months | $24.99/quarter |
| `nexus_premium_yearly` | 1 Year | $79.99/year |

---

## 6. 🔐 GOOGLE SIGN-IN SHA KEYS

Required for Google Sign-In to work on Android.

### Get SHA-1 and SHA-256 Keys

#### Debug Key (for development):
```bash
cd android
./gradlew signingReport
```

Or:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

#### Release Key (for production):
```bash
keytool -list -v -keystore /path/to/your/release-key.keystore -alias your-alias
```

### Add to Firebase Console
1. Go to Firebase Console → Project Settings
2. Select Android app
3. Add SHA-1 fingerprint
4. Add SHA-256 fingerprint
5. Download updated `google-services.json`
6. Replace `android/app/google-services.json`

### Verification Checklist
- [ ] Debug SHA-1 added to Firebase
- [ ] Debug SHA-256 added to Firebase
- [ ] Release SHA-1 added to Firebase
- [ ] Release SHA-256 added to Firebase
- [ ] Updated `google-services.json` in project
- [ ] Google Sign-In works on Android

---

## 📝 QUICK REFERENCE - IMPORTANT VALUES

| Item | Value |
|------|-------|
| Firebase Project | Nexus App |
| Support Email | nexusgodlydating@gmail.com |
| Android Package (Production) | com.nexus4singles.nexus |
| Android Package (Test) | com.nexusapptest.app |
| RevenueCat Apple Key | appl_dfjYQwnRsUjojfOSnYGqciVcGzx |
| RevenueCat Google Key | goog_mjvhTsGNNSzgnXyRVrIGjCmXwol |
| Premium Entitlement ID | premium |

---

## 🚀 LAUNCH CHECKLIST

Before going live:

- [ ] Firebase configured and tested
- [ ] Crashlytics enabled and receiving errors
- [ ] Contact Support Cloud Function deployed
- [ ] RevenueCat `_isProductionReady = true`
- [ ] All products created in App Store Connect
- [ ] All products created in Google Play Console
- [ ] All products configured in RevenueCat
- [ ] Google Sign-In SHA keys added (release + debug)
- [ ] App tested on real devices (iOS + Android)
- [ ] TestFlight / Internal Testing completed

---

*Last Updated: December 2024*
*Document Location: /nexus_app/PENDING_SETUP.md*
