# Android Setup Guide for Nexus App

## Required Permissions

The following permissions are automatically requested at runtime by the `permission_handler` package, but you need to declare them in `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Add inside <manifest> tag, before <application> -->

<!-- Camera Permission -->
<uses-permission android:name="android.permission.CAMERA"/>

<!-- Microphone Permission -->
<uses-permission android:name="android.permission.RECORD_AUDIO"/>

<!-- Storage Permissions -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>

<!-- For Android 13+ (API 33+) -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>

<!-- Internet Permission (usually already present) -->
<uses-permission android:name="android.permission.INTERNET"/>

<!-- Location Permission (optional, for nearby users) -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

## Minimum SDK Version

Update `android/app/build.gradle`:

```gradle
android {
    ...
    defaultConfig {
        ...
        minSdkVersion 21  // Required for some packages
        targetSdkVersion 34
        ...
    }
}
```

## Firebase Setup

1. Create a Firebase project at https://console.firebase.google.com
2. Add an Android app with package name: `com.nexus.app` (or your chosen package)
3. Download `google-services.json`
4. Place it in `android/app/google-services.json`
5. Update `android/build.gradle`:

```gradle
buildscript {
    dependencies {
        // Add this line
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

6. Update `android/app/build.gradle`:

```gradle
// Add at the bottom of the file
apply plugin: 'com.google.gms.google-services'
```

7. Run `flutterfire configure` to generate `firebase_options.dart`

## Image Cropper Configuration

Add to `android/app/src/main/AndroidManifest.xml` inside `<application>`:

```xml
<activity
    android:name="com.yalantis.ucrop.UCropActivity"
    android:screenOrientation="portrait"
    android:theme="@style/Theme.AppCompat.Light.NoActionBar"/>
```

## ProGuard Rules (Release Build)

Create or update `android/app/proguard-rules.pro`:

```
# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Image Cropper
-dontwarn com.yalantis.ucrop**
-keep class com.yalantis.ucrop** { *; }
-keep interface com.yalantis.ucrop** { *; }

# Audio Recording
-keep class com.ryanheise.audiorecorder.** { *; }
```

Update `android/app/build.gradle`:

```gradle
buildTypes {
    release {
        minifyEnabled true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

## Build Commands

```bash
# Get dependencies
flutter pub get

# Build APK (debug)
flutter build apk --debug

# Build APK (release)
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

## Troubleshooting

### Multidex issues
Add to `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        multiDexEnabled true
    }
}

dependencies {
    implementation 'androidx.multidex:multidex:2.0.1'
}
```

### Gradle version issues
Update `android/gradle/wrapper/gradle-wrapper.properties`:

```
distributionUrl=https\://services.gradle.org/distributions/gradle-8.0-all.zip
```

### Kotlin version issues
Update `android/build.gradle`:

```gradle
buildscript {
    ext.kotlin_version = '1.9.0'
}
```

### Permission denied on storage
For Android 10+, add to AndroidManifest.xml inside `<application>`:

```xml
android:requestLegacyExternalStorage="true"
```
