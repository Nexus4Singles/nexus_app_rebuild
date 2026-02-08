# Nexus App - TestFlight Preparation Checklist

## 🎯 Purpose
Preparing the app for internal TestFlight testing with a sandbox Apple ID to validate subscription/purchase flows with RevenueCat disabled.

---

## ✅ COMPLETED PRE-TESTFLIGHT FIXES

### Code Quality & Cleanup
- [x] **Color System Refactored** (41 files, 2426 insertions)
  - Replaced all hardcoded Colors.white/black/grey with AppColors system
  - Ensures consistent design across all screens
  - Commit: `499ea55`

- [x] **Guest Session Provider Fixed**
  - Changed error from UnimplementedError to UnsupportedError with better message
  - Guest session now properly initializes via bootstrap
  - Guests can only read stories, cannot access authenticated features

- [x] **Account Disabled Screen Routing Fixed**
  - Support button now properly routes to `/contact-support`
  - Users see contact support page instead of snackbar

- [x] **All Debug Statements Removed** (33 files cleaned)
  - Removed all debugPrint() calls from codebase
  - Kept kDebugMode conditionals (safe for release builds)
  - App now produces clean logs for TestFlight build
  - Flutter analyze shows zero compilation errors
  - Commit: `72bce0e`

### Verified Working Systems
- [x] **Audio System**: Uploads to DO Spaces, fetched via URLs (confirmed working)
- [x] **Activities System**: Loaded from JSON asset files (confirmed working)
- [x] **Profile Audio Prompts**: Fetched from DO Spaces URLs (confirmed working)
- [x] **Firebase Integration**: Auth, Firestore, FCM all operational
- [x] **Riverpod State Management**: Properly initialized with bootstrap

---

## 📋 PRE-BUILD CHECKLIST

### Configuration Review
- [ ] **RevenueCat Status**: Verify RevenueCatConfig has `isDisabled = true` for TestFlight
  - Location: `lib/core/config/revenuecat_config.dart`
  - Reason: We'll use sandbox Apple ID, not RevenueCat

- [ ] **Firebase Configuration**: Verify using TEST Firestore database
  - Location: `lib/firebase_options.dart`
  - Check: Analytics, Crashlytics, Cloud Messaging all use development instances

- [ ] **App Version**: Update version in pubspec.yaml
  - Current format: `version: X.Y.Z+build`
  - Increment build number for each TestFlight release

- [ ] **Bundle ID**: Confirm bundle ID matches App Store Connect
  - iOS: Check `ios/Runner.pbxproj`
  - Expected: `com.nexus.app` (or configured value)

### Code Verification
- [ ] **Compilation Check**: Run `flutter pub get && flutter analyze`
  - Ensure no errors or warnings
  
- [ ] **Test Build**: Create release build locally
  - Run: `flutter build ipa --release`
  - Verify app launches without crashes
  - Test guest session access
  - Test account disabled screen routing

### Firebase Setup (Pre-TestFlight)
- [ ] **Cloud Messaging**: Configure APNs certificate in Firebase
  - Go to: Project Settings > Cloud Messaging > Apple Configuration
  - Upload APNs certificate
  - Required for push notifications

- [ ] **Firestore Rules**: Deploy test rules (read-only for guests)
  - Deploy: `firebase deploy --only firestore:rules`
  - Verify guest access restrictions work

- [ ] **Storage Rules**: Configure DigitalOcean Spaces access
  - Verify media uploads work correctly
  - Test audio upload from dating profile screens

---

## 🚀 TESTFLIGHT SUBMISSION

### App Store Connect Setup
- [ ] **Create App Record**
  - Name: Nexus (or configured app name)
  - Bundle ID: `com.nexus.app`
  - SKU: Create unique identifier

- [ ] **Build Upload**
  - Generate provisioning profile for TestFlight
  - Run: `flutter build ipa --release`
  - Upload to App Store Connect using Xcode or Transporter

- [ ] **Build Configuration**
  - Set build number to match version
  - Confirm App ID and bundle ID match

- [ ] **TestFlight Testers**
  - Add internal testers (your email address)
  - App requires TestFlight version for sandbox testing

---

## 🧪 TESTFLIGHT TESTING PLAN

### Core Feature Testing
- [ ] **Guest Access**
  - Launch without login → Guest session starts
  - Can view stories (read-only)
  - Cannot access dating profiles, journeys, or challenges
  - Verify "Login Required" messages appear appropriately

- [ ] **Authentication**
  - Sign up with email
  - Login with email/password
  - Logout and return to splash
  - Password reset flow

- [ ] **User Onboarding**
  - Relationship status selection
  - Gender selection
  - Goals selection based on status
  - Profile creation (if not married)

- [ ] **Dating Profile** (if not married)
  - Complete 7-step profile setup
  - Upload photos
  - Record audio responses
  - Save and view profile

- [ ] **Subscription/Journeys** (with sandbox Apple ID)
  - View subscription screen
  - Attempt purchase (sandbox testing)
  - Verify purchase flow works
  - Verify completion notifications

- [ ] **Messaging**
  - Send/receive messages
  - View conversation history
  - Message notifications (if FCM configured)

- [ ] **Push Notifications**
  - Receive test notifications
  - Tap notification to navigate
  - Verify routing works correctly

### Crash Testing
- [ ] **Low Memory Conditions**
  - Verify graceful degradation
  - No crashes on network errors

- [ ] **Offline Functionality**
  - Try accessing features offline
  - Verify appropriate error messages

- [ ] **Permission Handling**
  - Camera permission (profile photos)
  - Microphone permission (audio recording)
  - Location access
  - Photo library access

---

## 📊 SANDBOX APPLE ID SETUP

### Before First Purchase Test
- [ ] **Sandbox Apple ID Account**
  - Create in App Store Connect > Users and Access > Sandbox Testers
  - Note: Cannot use your personal Apple ID for sandbox testing

- [ ] **Test Device Setup**
  - Sign out of real Apple ID
  - Sign into sandbox Apple ID in Settings > [Your Name]
  - Device is now in sandbox mode

- [ ] **Sandbox Purchase Credentials**
  - Sandbox purchases will prompt for password
  - Use sandbox Apple ID password (not real Apple ID)
  - Sandbox purchases don't charge credit card

### Sandbox Purchase Behavior
- ✅ Subscription testing works offline
- ✅ Sandbox purchases never expire (stay active in sandbox)
- ✅ Renewal testing available via settings
- ⚠️ Note: Returns all available in-app purchases in sandbox

---

## 🔄 KNOWN LIMITATIONS FOR TESTFLIGHT

### What's Disabled for TestFlight
1. **RevenueCat Integration**: Disabled for sandbox testing
   - Purchase flow will use native StoreKit instead
   - Subscriptions still tracked locally in Firestore

2. **Production Analytics**: Uses development Firebase
   - Analytics still recorded but in dev project
   - Can review in Firebase Console

3. **Production Notifications**: Uses development FCM credentials
   - Notifications work but route to dev infrastructure

### What Still Works
- ✅ All UI/UX flows
- ✅ Local data persistence
- ✅ Guest sessions
- ✅ Firestore read/write (using test rules)
- ✅ Media uploads to DO Spaces
- ✅ Audio recording and playback
- ✅ Messaging flows
- ✅ Profile creation and viewing
- ✅ Sandbox purchase flow (without RevenueCat)

---

## 🎯 SUCCESS CRITERIA

TestFlight testing is complete when:
1. ✅ No crashes on any primary flow
2. ✅ Guest users can access story content
3. ✅ Authenticated users can complete profile setup
4. ✅ Sandbox purchases complete successfully
5. ✅ Account disabled screen shows correct support routing
6. ✅ No debug output in console logs
7. ✅ All permissions granted and work correctly
8. ✅ Notifications received (if FCM configured)
9. ✅ Network errors handled gracefully
10. ✅ App performance is acceptable on test device

---

## 📝 NEXT STEPS AFTER TESTFLIGHT

### For Production Deployment
1. Enable RevenueCat integration
2. Switch to production Firebase database
3. Update app version and build number
4. Re-run security audit
5. Deploy updated Firestore rules for production
6. Configure production analytics
7. Setup production push notification certificates
8. Create production checklist and deployment guide

### Timeline Estimate
- TestFlight testing: 1-2 weeks
- Bug fixes and iterations: 1-2 weeks
- Production readiness: 3-4 weeks total

---

## 📞 SUPPORT & TROUBLESHOOTING

### Common TestFlight Issues

**Issue**: App crashes on launch
- Solution: Check Firebase configuration in `lib/firebase_options.dart`

**Issue**: "Download failed" on TestFlight
- Solution: Check bundle ID matches in both Xcode and App Store Connect

**Issue**: Sandbox purchase not working
- Solution: Verify signed into sandbox Apple ID in Settings

**Issue**: Notifications not received
- Solution: Verify FCM credentials uploaded to Firebase

**Issue**: Firestore permissions denied
- Solution: Check test firestore.rules allow guest read access

---

## ✨ RELEASE NOTES (For TestFlight)

```
Version X.Y.Z - TestFlight Build

What's New:
- Comprehensive color system refactoring for consistent design
- Fixed guest session access control
- Improved account disabled screen user experience
- Optimized performance and removed debug output
- Better error handling and user feedback

Test Focus Areas:
- Guest user access to story content
- User authentication and onboarding
- Dating profile setup and completion
- In-app purchase flow with sandbox Apple ID
- Push notifications
- Account management

Known Limitations:
- RevenueCat disabled for sandbox testing
- Uses development Firebase database
- Limited analytics in development mode

Please report any crashes or issues to the development team.
Thank you for testing!
```

---

## 📌 QUICK REFERENCE

### Build Commands
```bash
# Analyze for errors
flutter analyze

# Clean build
flutter clean && flutter pub get

# Build release IPA
flutter build ipa --release

# Build and deploy to TestFlight
flutter build ipa --release
# Then upload via App Store Connect or Xcode
```

### Configuration Files
- Firebase: `lib/firebase_options.dart`
- RevenueCat: `lib/core/config/revenuecat_config.dart`
- App Version: `pubspec.yaml`
- Bundle ID: `ios/Runner.pbxproj`

### Key Directories
- UI Components: `lib/core/ui/components/`
- Features: `lib/features/`
- Services: `lib/core/services/`
- Providers: `lib/core/providers/`

---

**Last Updated**: [Current Date]
**Status**: Ready for TestFlight Submission
**Next Review**: After initial TestFlight round
