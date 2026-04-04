import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'core/constants/app_constants.dart';
import 'core/session/effective_relationship_status_provider.dart';
import 'core/notifications/notification_provider.dart';
import 'core/providers/tab_selection_provider.dart';
import 'core/providers/service_providers.dart';
import 'core/providers/auth_provider.dart';
import 'safe_imports.dart';
import 'features/stories/presentation/screens/stories_screen.dart';
import 'features/dating_search/presentation/screens/new_dating_search_screen.dart';
import 'features/counselling/presentation/screens/book_marriage_coach_screen.dart'
    show BookMarriageCoachScreen;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final Map<NavTab, Widget> _tabScreenCache = {};

  @override
  void initState() {
    super.initState();
    // Always start on the home tab when AppShell is created (e.g. after login).
    // The global StateProvider may still hold a stale tab from a previous session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedTabProvider.notifier).state = NavTab.home;
    });
  }

  Widget _screenForTab(NavTab tab) {
    switch (tab) {
      case NavTab.home:
        return const HomeScreen();
      case NavTab.search:
        return const NewDatingSearchScreen();
      case NavTab.chats:
        return const ChatsScreen();
      case NavTab.stories:
        return const StoriesScreen();
      case NavTab.challenges:
        return const ChallengesScreen();
      case NavTab.counselling:
        if (FirebaseAuth.instance.currentUser?.email == 'nexus4singles@gmail.com') {
          return const BookMarriageCoachScreen();
        }
        return const _CounsellingComingSoon();
      case NavTab.profile:
        return const ProfileScreen();
    }
  }

  Widget _cachedScreenForTab(NavTab tab) {
    return _tabScreenCache.putIfAbsent(
      tab,
      () => KeyedSubtree(
        key: PageStorageKey<String>('app-shell-tab-${tab.name}'),
        child: _screenForTab(tab),
      ),
    );
  }

  IconData _iconForTab(NavTab tab) {
    switch (tab) {
      case NavTab.home:
        return Icons.home_outlined;
      case NavTab.search:
        return Icons.search_outlined;
      case NavTab.chats:
        return Icons.chat_bubble_outline;
      case NavTab.stories:
        return Icons.auto_stories_outlined;
      case NavTab.challenges:
        return Icons.emoji_events_outlined;
      case NavTab.counselling:
        return Icons.phone_in_talk_outlined;
      case NavTab.profile:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    // Initialize FCM for push notifications
    ref.watch(fcmInitializationProvider);

    final status = ref.watch(effectiveRelationshipStatusProvider);
    final selectedTab = ref.watch(selectedTabProvider);
    final tabConfigs = NavConfig.getTabsForStatus(status);

    // Watch unread message count for chat badge
    final unreadCountAsync = ref.watch(totalUnreadCountProvider);

    // ignore: avoid_print
    print(
      '[AppShell] rebuild: status=$status, tabs=${tabConfigs.map((t) => t.id).toList()}, selectedTab=$selectedTab',
    );

    // Validate that selected tab is in current tab configs
    bool isValidTab = tabConfigs.any((c) => c.id == selectedTab);
    if (!isValidTab) {
      // If selected tab is no longer valid (e.g., status changed), reset to home
      // ignore: avoid_print
      print(
        '[AppShell] Selected tab $selectedTab not in current configs, resetting to home',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedTabProvider.notifier).state = NavTab.home;
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final _index = tabConfigs.indexWhere((c) => c.id == selectedTab);
    final children = [
      for (final config in tabConfigs) _cachedScreenForTab(config.id),
    ];

    // Get unread count for badge
    int unreadCount = 0;
    unreadCountAsync.maybeWhen(
      data: (count) {
        unreadCount = count;
      },
      orElse: () {},
    );

    return Scaffold(
      body: IndexedStack(index: _index, children: children),
      floatingActionButton: null,
      bottomNavigationBar: _buildBottomNavBar(
        tabConfigs,
        _index,
        unreadCount,
        ref,
      ),
    );
  }

  Widget _buildBottomNavBar(
    List<NavTabConfig> tabs,
    int currentIndex,
    int unreadCount,
    WidgetRef ref,
  ) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) {
        ref.read(journeysOpenedFromHomeProvider.notifier).state = false;
        ref.read(selectedTabProvider.notifier).state = tabs[i].id;
      },
      type: BottomNavigationBarType.fixed,
      items:
          tabs
              .map(
                (c) => BottomNavigationBarItem(
                  icon: _buildNavIcon(c.id, unreadCount),
                  label: c.label,
                ),
              )
              .toList(),
    );
  }

  Widget _buildNavIcon(NavTab tab, int unreadCount) {
    final icon = Icon(_iconForTab(tab));
    if (tab != NavTab.chats || unreadCount <= 0) return icon;

    // Badge on the top-right corner of the icon, like WhatsApp
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          top: -4,
          right: -8,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Coming soon placeholder for the Counselling tab ──────────────────────────
class _CounsellingComingSoon extends StatelessWidget {
  const _CounsellingComingSoon();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.construction_rounded,
                  size: 72,
                  color: AppColors.primary.withOpacity(0.35),
                ),
                const SizedBox(height: 20),
                Text(
                  'Coming Soon',
                  style: AppTextStyles.headlineMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Speak to a Marriage Coach will be available in a future update.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.getTextSecondary(context),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
