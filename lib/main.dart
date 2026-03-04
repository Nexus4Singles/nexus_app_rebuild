import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:math' as math;

import 'firebase_options.dart';
import 'app_entry.dart';
import 'core/services/content_cache_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/revenuecat_service.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for flutter_cache_manager on iOS/macOS
  if (Platform.isIOS || Platform.isMacOS) {
    // sqflite is already initialized on Android, but on iOS we need to ensure it's ready
  }

  // Register background message handler BEFORE Firebase initialization
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize App Check safely for production
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
      // App Attest is registered in Firebase Console; DeviceCheck auth key is NOT uploaded.
      // Use App Attest for production (iOS 14+, real devices) and debug for development.
      appleProvider:
          kReleaseMode ? AppleProvider.appAttest : AppleProvider.debug,
    );
  } catch (e) {
    debugPrint('App Check initialization failed: $e');
  }

  await ContentCacheService().init();
  await RevenueCatService.init();

  // Note: appEntry() likely calls runApp(), so we handle global scaling inside the app root
  await appEntry();
}

/// A wrapper widget that applies global text scaling based on screen width.
/// This ensures a better UI/UX on small Android devices without breaking existing code.
class ResponsiveTextWrapper extends StatelessWidget {
  final Widget child;
  const ResponsiveTextWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          _calculateTextScale(MediaQuery.of(context).size.width),
        ),
      ),
      child: child,
    );
  }

  double _calculateTextScale(double width) {
    // Base width for scaling calculations (standard modern smartphone width)
    const double baseWidth = 390.0;

    // We use a milder scaling factor to prevent extreme changes
    double scaleFactor = 1 + (width / baseWidth - 1) * 0.5;

    // Clamp the scale factor between 0.88 and 1.10
    // This prevents text from becoming too tiny on small phones
    // or too massive on large ones.
    return math.max(0.88, math.min(1.10, scaleFactor));
  }
}
