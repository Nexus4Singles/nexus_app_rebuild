# Nexus 2.0 - Flutter Project

## Quick Start

### Step 1: Extract and Navigate
```bash
# Unzip the file
unzip nexus_app_v2.zip

# Navigate to project
cd nexus_app
```

### Step 2: Create Flutter Platform Folders
```bash
# This creates the android/ and ios/ folders with correct bundle ID
flutter create --org com.nexus4singles --project-name nexus .
```

### Step 3: Get Dependencies
```bash
flutter pub get
```

### Step 4: Firebase Setup
```bash
# Make setup script executable
chmod +x firebase_setup.sh

# Run it
./firebase_setup.sh
```

### Step 5: Enable Firebase in Code
After firebase_setup.sh completes, open `lib/main.dart` and:

1. Uncomment line ~31:
```dart
import 'firebase_options.dart';
```

2. Uncomment lines ~47-49:
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

### Step 6: Run the App
```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

---

## Project Configuration

| Setting | Value |
|---------|-------|
| Bundle ID (Android) | `com.nexus4singles.nexus` |
| Bundle ID (iOS) | `com.nexus4singles.nexus` |
| Firebase Project | Nexus App |
| Min iOS | 12.0 |
| Min Android SDK | 21 |

---

## Project Structure

```
nexus_app/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── core/                     # Shared code
│   │   ├── models/               # Data models
│   │   ├── providers/            # Riverpod providers
│   │   ├── services/             # Business logic
│   │   ├── theme/                # Colors, styles, themes
│   │   ├── widgets/              # Reusable widgets
│   │   ├── router/               # Navigation
│   │   └── constants/            # App constants
│   └── features/                 # Feature modules
│       ├── auth/                 # Login, signup
│       ├── onboarding/           # Survey, splash
│       ├── home/                 # Home screen
│       ├── search/               # Dating search
│       ├── chats/                # Messaging
│       ├── profile/              # User profile
│       ├── challenges/           # Journeys
│       ├── assessment/           # Assessments
│       ├── stories/              # Weekly stories
│       ├── subscription/         # Premium
│       ├── notifications/        # Notifications
│       └── settings/             # Settings, support
├── assets/
│   ├── config/                   # JSON configurations
│   │   ├── assessments/          # Assessment configs
│   │   ├── journeys/             # Journey configs
│   │   ├── engagement/           # Stories, polls
│   │   └── onboarding/           # Onboarding lists
│   ├── images/                   # App images
│   └── fonts/                    # Custom fonts
├── firebase_functions/           # Cloud Functions
├── docs/                         # Setup documentation
├── pubspec.yaml                  # Dependencies
├── firebase_setup.sh             # Firebase setup script
└── SETUP_PENDING.md              # Pending tasks checklist
```

---

## Key Files

| Purpose | File |
|---------|------|
| RevenueCat Config | `lib/core/services/revenuecat_service.dart` |
| Theme/Colors | `lib/core/theme/app_colors.dart` |
| Routes | `lib/core/router/app_router.dart` |
| User Model | `lib/core/models/user_model.dart` |
| Auth Provider | `lib/core/providers/auth_provider.dart` |

---

## Pending Setup (see SETUP_PENDING.md)

- [ ] Firebase configuration
- [ ] SHA fingerprints (Android)
- [ ] Crashlytics setup
- [ ] Contact Support Cloud Function
- [ ] RevenueCat production enable
- [ ] Push notifications
- [ ] App Store submission

---

## Support

Email: nexusgodlydating@gmail.com
