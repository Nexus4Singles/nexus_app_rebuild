import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

/// Provider to manage which tab is currently selected in the AppShell
/// This allows any screen to request a tab switch while maintaining the BottomNavigationBar visibility
final selectedTabProvider = StateProvider<NavTab>((ref) => NavTab.home);
