import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:country_picker/country_picker.dart';
import 'dart:math' as math;

import 'app_shell.dart';
import 'core/bootstrap/firebase_bootstrap.dart';
import 'core/bootstrap/firebase_ready_provider.dart';
import 'core/router/app_router.dart';
import 'core/notifications/notification_service.dart' show navigatorKey;
import 'core/session/guest_session_provider.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/chat_media_upload_lifecycle_handler.dart';
import 'core/email_verification/email_verification_gate.dart';
import 'features/launch/presentation/app_launch_gate.dart';
import 'features/app_update/presentation/screens/app_update_checker.dart';
import 'core/providers/auth_provider.dart';
import 'core/services/chat_service.dart';
import 'safe_imports.dart';

Future<void> appEntry() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseReady = false;
  try {
    await initFirebaseSafely();
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false;
  }

  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      firebaseReadyProvider.overrideWith((ref) => firebaseReady),
    ],
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const _RootApp()),
  );
}

class _RootApp extends ConsumerWidget {
  const _RootApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return AppUpdateChecker(
      child: MaterialApp(
        localizationsDelegates: const [
          CountryLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        onGenerateRoute: onGenerateRoute,
        builder: (context, child) {
          // Safe Text Scaling Logic
          // Calculates a scale factor based on screen width to prevent
          // oversized fonts on small Android devices.
          final double width = MediaQuery.of(context).size.width;
          const double baseWidth = 390.0;
          double scaleFactor = 1 + (width / baseWidth - 1) * 0.5;
          double finalScale = math.max(0.88, math.min(1.10, scaleFactor));

          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(finalScale)),
            child: DefaultTextStyle(
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              child: ChatMediaUploadLifecycleHandler(
                child: AppLifecycleListener(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          );
        },
        home: const EmailVerificationGate(child: AppLaunchGate()),
      ),
    );
  }
}

/// Tracks app lifecycle and updates user's last active status
class AppLifecycleListener extends ConsumerStatefulWidget {
  final Widget child;

  const AppLifecycleListener({super.key, required this.child});

  @override
  ConsumerState<AppLifecycleListener> createState() =>
      _AppLifecycleListenerState();
}

class _AppLifecycleListenerState extends ConsumerState<AppLifecycleListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateLastActive();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - update last active
        _updateLastActive();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        // App went to background
        break;
    }
  }

  Future<void> _updateLastActive() async {
    try {
      // Get current user ID from auth
      final authService = ref.read(authServiceProvider);
      final userId = authService.currentUser?.uid;

      if (userId != null && userId.isNotEmpty) {
        // Update last active timestamp in Firestore
        final chatService = ChatService();
        await chatService.updateUserLastActive(userId);
      }
    } catch (e) {
      debugPrint('Error updating last active: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
