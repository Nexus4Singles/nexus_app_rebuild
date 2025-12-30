// ============================================================================
// THIS IS A TEMPLATE FILE - DO NOT USE DIRECTLY
// ============================================================================
//
// This file shows what firebase_options.dart will look like after you run:
//   flutterfire configure
//
// The actual file will be generated automatically with YOUR Firebase project's
// real API keys and configuration values.
//
// DELETE THIS FILE after running flutterfire configure - it will create the
// real firebase_options.dart in its place.
//
// ============================================================================

// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ⚠️ THESE ARE PLACEHOLDER VALUES - REAL VALUES WILL BE GENERATED
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY_WILL_BE_HERE',
    appId: '1:123456789:android:abcdef123456',
    messagingSenderId: '123456789',
    projectId: 'your-firebase-project-id',
    storageBucket: 'your-firebase-project-id.appspot.com',
  );

  // ⚠️ THESE ARE PLACEHOLDER VALUES - REAL VALUES WILL BE GENERATED
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY_WILL_BE_HERE',
    appId: '1:123456789:ios:abcdef123456',
    messagingSenderId: '123456789',
    projectId: 'your-firebase-project-id',
    storageBucket: 'your-firebase-project-id.appspot.com',
    iosClientId: 'your-ios-client-id.apps.googleusercontent.com',
    iosBundleId: 'com.yourcompany.nexus',
  );
}
