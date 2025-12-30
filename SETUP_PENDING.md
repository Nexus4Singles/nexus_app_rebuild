# Nexus 2.0 - Pending Setup Items

This document tracks all setup and configuration tasks that need to be completed before launch.

---

## 📋 Status Legend
- ⬜ Not Started
- 🟡 In Progress  
- ✅ Complete

---

## 1. Firebase Setup ⬜

### 1.1 Bundle ID Decision ✅ DECIDED

**Decision: Keep existing bundle ID for app update**

| Platform | Bundle ID |
|----------|-----------|
| **Android** | `com.nexus4singles.nexus` |
| **iOS** | `com.nexus4singles.nexus` |

**Benefits:**
- Faster app review (update vs new app)
- Existing users get automatic update
- Retain app store history
- Same Firebase project connection

### 1.2 Create Flutter Project Structure

**Run these commands on your local machine:**

```bash
# Navigate to where you want the project
cd /path/to/your/projects

# Create Flutter project with correct bundle ID
flutter create --org com.nexus4singles --project-name nexus nexus_app

# OR if project already exists, just ensure the folders are created:
cd nexus_app
flutter pub get
```

**This creates:**
- `android/` folder with package `com.nexus4singles.nexus`
- `ios/` folder with bundle ID `com.nexus4singles.nexus`

### 1.3 FlutterFire Configuration

**Firebase Project:** `Nexus App`

**Steps:**
```bash
# 1. Install FlutterFire CLI (one-time)
dart pub global activate flutterfire_cli

# 2. Add to PATH (add to ~/.zshrc or ~/.bashrc for permanence)
export PATH="$PATH":"$HOME/.pub-cache/bin"

# 3. Navigate to project
cd /path/to/nexus_app

# 4. Run configure
flutterfire configure
```

**During configuration, use these values:**
1. Select project: `Nexus App`
2. Select platforms: `android`, `ios`
3. Android package: `com.nexus4singles.nexus`
4. iOS bundle: `com.nexus4singles.nexus`

**After configuration:**
1. Open `lib/main.dart`
2. Uncomment line ~31: `import 'firebase_options.dart';`
3. Uncomment lines ~47-49: `Firebase.initializeApp(...)` block
4. Run: `flutter pub get`

### 1.4 SHA-1/SHA-256 Fingerprints (Android)

**Required for:** Google Sign-In, App Links

```bash
# Debug key (for development)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Release key (for production)
keytool -list -v -keystore /path/to/your/release.keystore -alias your-alias
```

**Add fingerprints to:**
1. Firebase Console → Project Settings → Your Apps → Android app
2. Add both SHA-1 and SHA-256

---

## 2. Firebase Crashlytics ⬜

### 2.1 Dependencies ✅ Already Added

`firebase_crashlytics: ^3.4.9` is already in pubspec.yaml

### 2.2 Initialize Crashlytics

**File:** `lib/main.dart`

Add import:
```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
```

Update main() function:
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ... existing code ...
  
  // Initialize Firebase (uncomment after flutterfire configure)
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
  
  runApp(
    const ProviderScope(
      child: NexusApp(),
    ),
  );
}
```

### 2.3 Update Error Handler Service

**File:** `lib/core/services/error_handler_service.dart`

Uncomment the Crashlytics line in `logError()`:
```dart
void logError(dynamic error, [StackTrace? stackTrace]) {
  debugPrint('ERROR: $error');
  
  // Send to Firebase Crashlytics in production
  FirebaseCrashlytics.instance.recordError(error, stackTrace);
}
```

### 2.4 Enable in Firebase Console

1. Go to Firebase Console → Crashlytics
2. Click "Enable Crashlytics"
3. Build and run app to verify connection

---

## 3. Contact Support Cloud Function ⬜

### 3.1 Setup Cloud Functions

```bash
# Navigate to project root
cd /path/to/nexus_app

# Initialize Cloud Functions (if not already)
firebase init functions

# Select: TypeScript
# Install dependencies: Yes
```

### 3.2 Create Email Function

**File:** `functions/src/index.ts`

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as nodemailer from 'nodemailer';

admin.initializeApp();

// Configure email transporter (use your email service)
// Option 1: Gmail (requires app password)
// Option 2: SendGrid, Mailgun, etc.
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'nexusgodlydating@gmail.com',
    pass: 'YOUR_APP_PASSWORD', // Use environment variable in production
  },
});

// Trigger when new support request is created
export const sendSupportEmail = functions.firestore
  .document('supportRequests/{requestId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    
    const mailOptions = {
      from: 'Nexus App <noreply@nexusapp.com>',
      to: 'nexusgodlydating@gmail.com',
      subject: `[Support] ${data.category}: ${data.subject}`,
      html: `
        <h2>New Support Request</h2>
        <hr>
        <p><strong>From:</strong> ${data.username} (${data.userEmail})</p>
        <p><strong>User ID:</strong> ${data.userId}</p>
        <p><strong>Category:</strong> ${data.category}</p>
        <p><strong>Subject:</strong> ${data.subject}</p>
        <p><strong>Platform:</strong> ${data.platform}</p>
        <p><strong>App Version:</strong> ${data.appVersion}</p>
        <hr>
        <h3>Message:</h3>
        <p>${data.message}</p>
        <hr>
        <p><small>Request ID: ${context.params.requestId}</small></p>
        <p><small>Submitted: ${data.createdAt?.toDate?.() || 'Unknown'}</small></p>
      `,
    };
    
    try {
      await transporter.sendMail(mailOptions);
      
      // Update request status
      await snap.ref.update({ 
        emailSent: true,
        emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      console.log('Support email sent successfully');
    } catch (error) {
      console.error('Error sending support email:', error);
      
      await snap.ref.update({ 
        emailSent: false,
        emailError: error.message,
      });
    }
  });

// Optional: Auto-reply to user
export const sendAutoReply = functions.firestore
  .document('supportRequests/{requestId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    
    if (!data.userEmail || data.userEmail === 'Not provided') {
      return;
    }
    
    const mailOptions = {
      from: 'Nexus Support <nexusgodlydating@gmail.com>',
      to: data.userEmail,
      subject: 'We received your support request',
      html: `
        <h2>Thank you for reaching out!</h2>
        <p>Hi ${data.username},</p>
        <p>We've received your support request regarding "<strong>${data.subject}</strong>".</p>
        <p>Our team will review your message and get back to you within 24-48 hours.</p>
        <br>
        <p>For reference, here's a copy of your message:</p>
        <blockquote style="background: #f5f5f5; padding: 15px; border-radius: 8px;">
          ${data.message}
        </blockquote>
        <br>
        <p>With love,<br>The Nexus Team 💕</p>
      `,
    };
    
    try {
      await transporter.sendMail(mailOptions);
      console.log('Auto-reply sent to user');
    } catch (error) {
      console.error('Error sending auto-reply:', error);
    }
  });
```

### 3.3 Install Dependencies

```bash
cd functions
npm install nodemailer @types/nodemailer
```

### 3.4 Deploy Functions

```bash
firebase deploy --only functions
```

### 3.5 Gmail App Password Setup

1. Go to Google Account → Security
2. Enable 2-Step Verification (if not already)
3. Go to App Passwords
4. Create new app password for "Mail"
5. Use this password in the Cloud Function

**Better for production:** Use environment variables:
```bash
firebase functions:config:set email.password="YOUR_APP_PASSWORD"
```

Then in code:
```typescript
const password = functions.config().email.password;
```

---

## 4. RevenueCat Production ⬜

### 4.1 App Store Connect Setup

**Create Products:**
| Product ID | Type | Price |
|------------|------|-------|
| `nexus_premium_monthly` | Auto-Renewable | $X.XX |
| `nexus_premium_quarterly` | Auto-Renewable | $X.XX |
| `nexus_premium_yearly` | Auto-Renewable | $X.XX |

**Journey Packages (one-time):**
Use product IDs from JSON config files, e.g.:
- `co_parenting_peace_plan`
- `appreciation_friendship_positive_regard`
- etc.

### 4.2 Google Play Console Setup

Same products as App Store Connect.

### 4.3 RevenueCat Dashboard

1. Add products from both stores
2. Create offerings
3. Link to entitlements

### 4.4 Enable in Code

**File:** `lib/core/services/revenuecat_service.dart`

Change:
```dart
static const bool _isProductionReady = false;
```

To:
```dart
static const bool _isProductionReady = true;
```

---

## 5. Google Sign-In ⬜

### 5.1 Firebase Console

1. Go to Authentication → Sign-in method
2. Enable Google provider
3. Add support email

### 5.2 iOS Setup

**File:** `ios/Runner/Info.plist`

Add URL scheme (get from GoogleService-Info.plist):
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.XXXXXX</string>
    </array>
  </dict>
</array>
```

### 5.3 Android Setup

- SHA-1 fingerprint must be added to Firebase (see 1.5)
- Download updated `google-services.json` after adding fingerprint

---

## 6. Push Notifications ⬜

### 6.1 iOS (APNs)

1. Apple Developer Portal → Certificates
2. Create APNs Key or Certificate
3. Upload to Firebase Console → Project Settings → Cloud Messaging

### 6.2 Android (FCM)

- Works automatically with `google-services.json`

### 6.3 Code Implementation

Add to `lib/main.dart`:
```dart
import 'package:firebase_messaging/firebase_messaging.dart';

// In main():
final messaging = FirebaseMessaging.instance;
await messaging.requestPermission();
final token = await messaging.getToken();
print('FCM Token: $token');
```

---

## 7. App Store / Play Store Submission ⬜

### 7.1 Pre-submission Checklist

- [ ] Bundle ID finalized
- [ ] App icons (all sizes)
- [ ] Splash screen
- [ ] Screenshots for all device sizes
- [ ] App description
- [ ] Privacy policy URL
- [ ] Terms of service URL
- [ ] Support email configured

### 7.2 iOS Specific

- [ ] App Store Connect listing created
- [ ] TestFlight build uploaded
- [ ] Beta testing complete
- [ ] App Review submission

### 7.3 Android Specific

- [ ] Play Console listing created
- [ ] Signed release APK/AAB
- [ ] Internal/Closed testing complete
- [ ] Production release

---

## Quick Reference: File Locations

| Item | File Path |
|------|-----------|
| Firebase Options | `lib/firebase_options.dart` (generated) |
| Main Entry | `lib/main.dart` |
| RevenueCat Config | `lib/core/services/revenuecat_service.dart` |
| Error Handler | `lib/core/services/error_handler_service.dart` |
| Contact Support | `lib/features/settings/presentation/screens/contact_support_screen.dart` |
| Android Manifest | `android/app/src/main/AndroidManifest.xml` |
| iOS Info.plist | `ios/Runner/Info.plist` |
| Build Gradle | `android/app/build.gradle` |

---

## Configuration Summary

| Setting | Value |
|---------|-------|
| **Bundle ID (Android)** | `com.nexus4singles.nexus` |
| **Bundle ID (iOS)** | `com.nexus4singles.nexus` |
| **Firebase Project** | Nexus App |
| **Support Email** | nexusgodlydating@gmail.com |
| **App Version** | 2.0.0 |

**RevenueCat Keys:** (inactive until `_isProductionReady = true`)
- Apple: `appl_dfjYQwnRsUjojfOSnYGqciVcGzx`
- Google: `goog_mjvhTsGNNSzgnXyRVrIGjCmXwol`

---

*Last Updated: December 2024*
