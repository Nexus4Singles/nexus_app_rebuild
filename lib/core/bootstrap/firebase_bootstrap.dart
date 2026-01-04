import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../constants/dev_flags.dart';

Future<void> initFirebaseSafely() async {
  if (DEV_DISABLE_FIREBASE) {
    if (kDebugMode) debugPrint("🚫 Firebase disabled in dev mode.");
    return;
  }

  try {
    await Firebase.initializeApp();
    if (kDebugMode) debugPrint("✅ Firebase initialized.");
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('⚠️ Firebase init failed: $e');
      debugPrint(st.toString());
    }
  }
}
