# Fix for TARGET_BUILD_DIR Build Error

## Symptoms
- Xcode build completes successfully (after ~3580s)
- Error: "Xcode build is missing expected TARGET_BUILD_DIR build setting"
- App fails to launch on simulator

## Root Cause
Flutter cannot parse Xcode's build output or find the built app bundle, even though Xcode compilation succeeded.

## Fix Steps (Run these commands in order)

### Step 1: Kill any stuck processes
```bash
killall -9 Xcode xcodebuild pod flutter dart
```

### Step 2: Clean all build artifacts
```bash
cd /Users/aybaj/Documents/nexus_app_v2
rm -rf build/
rm -rf ios/Pods
rm -rf ios/Podfile.lock  
rm -rf ios/.symlinks
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
rm -rf .dart_tool/
rm -rf ~/.pub-cache/hosted/pub.dartlang.org/.cache
```

### Step 3: Regenerate Flutter configuration
```bash
flutter pub get
```

### Step 4: Install CocoaPods (no --repo-update to save time)
```bash
cd ios
pod install
cd ..
```

### Step 5: Try building for simulator
```bash
flutter build ios --simulator --debug
```

### Step 6: Run the app
```bash
flutter run
````

## Alternative: Use Xcode Directly

If the above doesn't work, try building directly in Xcode:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select a simulator (iPhone 15 Pro Max)
3. Click Product > Clean Build Folder (Cmd+Shift+K)
4. Click Product > Build (Cmd+B)
5. If build succeeds, close Xcode
6. Run `flutter run` from terminal

## Quick Fix Script

I've created `fix_xcode_build.sh` in your project root. After killing any stuck processes, run:

```bash
cd /Users/aybaj/Documents/nexus_app_v2
bash fix_xcode_build.sh
```

## If Nothing Works

The nuclear option:
```bash
# Reinstall CocoaPods
sudo gem install cocoapods

# Clear all Flutter/Xcode caches
rm -rf ~/Library/Developer/Xcode/DerivedData/*
flutter clean
rm -rf ~/.pub-cache

# Start fresh
flutter pub get
cd ios && pod install && cd ..
flutter run
```
