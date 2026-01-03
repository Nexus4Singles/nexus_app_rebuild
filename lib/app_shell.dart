import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/session/effective_relationship_status_provider.dart';
import 'safe_imports.dart';
import 'features/stories/presentation/screens/stories_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  Widget _screenForTab(NavTab tab) {
    switch (tab) {
      case NavTab.home:
        return const HomeScreen();
      case NavTab.search:
        return const SearchScreen();
      case NavTab.chats:
        return const ChatsScreen();
      case NavTab.stories:
        return const StoriesScreen();
      case NavTab.challenges:
        return const ChallengesScreen();
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
      case NavTab.profile:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(effectiveRelationshipStatusProvider);
    final tabConfigs = NavConfig.getTabsForStatus(status);

    if (_index >= tabConfigs.length) _index = 0;

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
        onTap: (i) => setState(() => _index = i),
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
