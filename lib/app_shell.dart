import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/session/effective_relationship_status_provider.dart';
import 'core/notifications/notification_provider.dart';
import 'core/providers/tab_selection_provider.dart';
import 'safe_imports.dart';
import 'features/stories/presentation/screens/stories_screen.dart';
import 'features/dating_search/presentation/screens/new_dating_search_screen.dart';
import 'features/counselling/presentation/screens/book_marriage_coach_screen.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize FCM for push notifications
    ref.watch(fcmInitializationProvider);

    final status = ref.watch(effectiveRelationshipStatusProvider);
    final selectedTab = ref.watch(selectedTabProvider);
    final tabConfigs = NavConfig.getTabsForStatus(status);

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
    final currentTab = tabConfigs[_index].id;

    return Scaffold(
      body: _screenForTab(currentTab),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final ctx = context;
          await showModalBottomSheet<void>(
            context: ctx,
            builder:
                (_) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        title: const Text('Push /chats/abc'),
                        onTap: () => Navigator.of(ctx).pushNamed('/chats/abc'),
                      ),
                      ListTile(
                        title: const Text('Push /profile/u123'),
                        onTap:
                            () => Navigator.of(ctx).pushNamed('/profile/u123'),
                      ),
                      ListTile(
                        title: const Text('Push /journey/p987'),
                        onTap:
                            () => Navigator.of(ctx).pushNamed('/journey/p987'),
                      ),
                      ListTile(
                        title: const Text('Push /journey/p987/session/2'),
                        onTap:
                            () => Navigator.of(
                              ctx,
                            ).pushNamed('/journey/p987/session/2'),
                      ),
                      ListTile(
                        title: const Text('Push /story/s55'),
                        onTap: () => Navigator.of(ctx).pushNamed('/story/s55'),
                      ),
                      ListTile(
                        title: const Text('Push /story/s55/poll'),
                        onTap:
                            () =>
                                Navigator.of(ctx).pushNamed('/story/s55/poll'),
                      ),
                    ],
                  ),
                ),
          );
        },
        child: const Icon(Icons.bug_report),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap:
            (i) =>
                ref.read(selectedTabProvider.notifier).state = tabConfigs[i].id,
        type: BottomNavigationBarType.fixed,
        items:
            tabConfigs
                .map(
                  (c) => BottomNavigationBarItem(
                    icon: Icon(_iconForTab(c.id)),
                    label: c.label,
                  ),
                )
                .toList(),
      ),
    );
  }
}
