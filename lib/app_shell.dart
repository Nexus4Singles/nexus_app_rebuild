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
import 'features/counselling/presentation/screens/book_marriage_coach_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final Map<NavTab, Widget> _tabScreenCache = {};

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
        return const BookMarriageCoachScreen();
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

    // Reset tab to home when user logs in to ensure consistent starting state
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      next.whenData((user) {
        if (user != null && !user.isAnonymous) {
          // User just logged in, reset tab to home
          if (ref.read(selectedTabProvider) != NavTab.home) {
            ref.read(selectedTabProvider.notifier).state = NavTab.home;
          }
        }
      });
    });

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
