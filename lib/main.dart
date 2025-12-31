import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/bootstrap/firebase_bootstrap.dart';

import 'app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebaseSafely();

  // Firebase init intentionally deferred/optional during rebuild.
  // When you’re ready, we’ll wire it properly with firebase_options.dart.
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: AppShell()));
}
