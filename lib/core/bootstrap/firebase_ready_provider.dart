import 'package:flutter_riverpod/flutter_riverpod.dart';

import "package:flutter/foundation.dart";

final firebaseReadyProvider = StateProvider<bool>(
  (ref) => kDebugMode ? true : false,
);
