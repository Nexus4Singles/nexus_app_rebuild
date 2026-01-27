import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:country_picker/country_picker.dart';

import 'app_shell.dart';
import 'core/bootstrap/firebase_bootstrap.dart';
import 'core/bootstrap/firebase_ready_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/session/guest_session_provider.dart';
import 'core/theme/theme_provider.dart';
import 'features/launch/presentation/app_launch_gate.dart';
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

    return MaterialApp(
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
        final scheme = Theme.of(context).colorScheme;
        return DefaultTextStyle(
          style: TextStyle(color: scheme.onSurface),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppLaunchGate(),
    );
  }
}
