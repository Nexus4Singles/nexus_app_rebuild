# iOS Setup Guide for Nexus App

## Required Permissions

After creating the iOS folder with `flutter create .` or `flutter build ios`, add the following to `ios/Runner/Info.plist`:

```xml
<!-- Add these inside the <dict> tag -->

<!-- Camera Permission -->
<key>NSCameraUsageDescription</key>
<string>Nexus needs camera access to take profile photos</string>

<!-- Photo Library Permission -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Nexus needs photo library access to upload profile photos</string>

<!-- Microphone Permission -->
<key>NSMicrophoneUsageDescription</key>
<string>Nexus needs microphone access to record audio responses</string>

<!-- Location Permission (optional, for nearby users) -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Nexus uses your location to find nearby users</string>
```

## Podfile Configuration

Update `ios/Podfile` with the following:

```ruby
platform :ios, '13.0'

# Add at the end of the file, inside the target block:
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
        'PERMISSION_MICROPHONE=1',
        'PERMISSION_PHOTOS=1',
      ]
    end
  end
end
```

## Firebase Setup

1. Create a Firebase project at https://console.firebase.google.com
2. Add an iOS app with bundle ID: `com.nexus.app` (or your chosen bundle ID)
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/GoogleService-Info.plist`
5. Run `flutterfire configure` to generate `firebase_options.dart`

## Build Commands

```bash
# Get dependencies
flutter pub get

# Generate iOS folder if it doesn't exist
flutter create --platforms=ios .

# Build iOS app
flutter build ios --debug

# Or open in Xcode
open ios/Runner.xcworkspace
```

## Image Cropper iOS Configuration

Add to `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>remote-notification</string>
</array>
```

## Troubleshooting

### "No provisioning profile" error
- Sign in to Xcode with your Apple Developer account
- Select a team in Runner > Signing & Capabilities

### CocoaPods issues
```bash
cd ios
pod deintegrate
pod install --repo-update
```

### Permission denied errors
- Ensure Info.plist has all required permission descriptions
- Check that permission_handler is properly configured
