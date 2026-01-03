import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_shell.dart';
import 'core/bootstrap/bootstrap_gate.dart';
import 'features/guest/guest_entry_gate.dart';
import 'features/launch/presentation/app_launch_gate.dart';
import 'core/bootstrap/firebase_bootstrap.dart';
import 'core/bootstrap/firebase_ready_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/session/guest_session_provider.dart';
import 'safe_imports.dart';

Future<void> appEntry() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: _AppBootstrap()));
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );

    bool firebaseReady = false;
    try {
      await initFirebaseSafely();
      firebaseReady = true;
    } catch (_) {
      firebaseReady = false;
    }

    container.read(firebaseReadyProvider.notifier).state = firebaseReady;

    runApp(
      UncontrolledProviderScope(
        container: container,
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
          themeMode: ThemeMode.light,
          theme: AppTheme.lightTheme,
          onGenerateRoute: onGenerateRoute,
          home: const AppLaunchGate(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Minimal instant splash while boot runs
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }
}
