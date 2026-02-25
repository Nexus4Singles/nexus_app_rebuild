import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';

import 'firebase_options.dart';
import 'app_entry.dart';
import 'core/services/content_cache_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/revenuecat_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for flutter_cache_manager on iOS/macOS
  if (Platform.isIOS || Platform.isMacOS) {
    // sqflite is already initialized on Android, but on iOS we need to ensure it's ready
    // The package handles this automatically when initialized, but we ensure early binding
  }

  // Register background message handler BEFORE Firebase initialization
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize App Check with provider selection based on platform
  // Uses DeviceCheck on iOS and Play Integrity API on Android
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.deviceCheck,
  );

  await ContentCacheService().init();
  await RevenueCatService.init();
  await appEntry();
}
