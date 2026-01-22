import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';

import 'package:nexus_app_min_test/core/session/is_guest_provider.dart';
import 'package:nexus_app_min_test/core/providers/auth_provider.dart';

import 'package:nexus_app_min_test/core/session/relationship_status_key.dart';

import 'package:nexus_app_min_test/features/stories/data/story_repository.dart';
import 'package:nexus_app_min_test/features/stories/domain/story_models.dart';
import 'package:nexus_app_min_test/features/stories/presentation/screens/stories_screen.dart';

import 'package:nexus_app_min_test/features/journeys/data/journey_repository.dart';
import 'package:nexus_app_min_test/features/journeys/domain/journey_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<String> _homeDisplayNameForUser(User? u) async {
  if (u == null) return '';
  
  // First check Firebase Auth displayName
  final dn = (u.displayName ?? '').trim();
  if (dn.isNotEmpty) return dn.split(RegExp(r'\s+')).first.trim();

  // Firestore fallback - prioritize username for v2 users
  try {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
    final data = doc.data();
    if (data != null) {
      String pick(List<String> keys) {
        for (final k in keys) {
          final v = data[k];
          if (v == null) continue;
          final t = v.toString().trim();
          if (t.isNotEmpty) return t;
        }
        return '';
      }

      // Prioritize username, then name, then other variants
      final candidate = pick([
        'username',
        'user_name',
        'name',
        'fullName',
        'full_name',
        'displayName',
        'display_name',
      ]);

      if (candidate.isNotEmpty) {
        return candidate.split(RegExp(r'\s+')).first.trim();
      }
    }
  } catch (_) {}

  // Only use email as absolute last resort if nothing else is available
  return '';
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<String> _loadStatusKeyFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getString('relationshipStatus') ??
        prefs.getString('relationship_status') ??
        prefs.getString('user_relationship_status') ??
        prefs.getString('onboarding_relationship_status') ??
        prefs.getString('category') ??
        prefs.getString('user_category') ??
        '';
    return relationshipStatusKeyFromString(raw);
  }

  Future<String?> _loadActiveJourneyIdFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getString('activeJourneyId') ??
        prefs.getString('active_journey_id') ??
        prefs.getString('activeJourney') ??
        prefs.getString('active_journey');
    final v = raw?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  String _assessmentTitleForKey(String key) {
    if (key == 'married') return 'Marriage Health Check';
    if (key == 'divorced' || key == 'widowed')
      return 'Remarriage Readiness Test';
    return 'Marriage Readiness Test';
  }

  String _assessmentDescForKey(String key) {
    if (key == 'married') return 'Find out how healthy your marriage is';
    if (key == 'divorced' || key == 'widowed') {
      return 'Find out how ready you are to get married again';
    }
    return 'Find out how ready you are for the marriage you desire';
  }

  String _journeysCopyForKey(String key) {
    if (key == 'married') {
      return 'Strengthen your marriage by equipping yourself with practical knowledge and guidance required to navigate every aspect of married life';
    }
    if (key == 'divorced') {
      return 'Rebuild with clarity and confidence by gaining practical guidance for healing, growth, and healthier relationships ahead';
    }
    if (key == 'widowed') {
      return 'Find steady guidance and practical support as you navigate life, healing, and relationships after spousal loss';
    }
    return 'Equip yourself with the practical knowledge, clarity, and confidence you need to choose a life partner and navigate marriage';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final theme = Theme.of(context);

    // Use the canonical guest logic (respects `force_guest` etc.)
    // This now watches auth state internally, so it auto-updates on login/logout
    final isGuestAsync = ref.watch(isGuestProvider);
    final isGuest = isGuestAsync.maybeWhen(data: (v) => v, orElse: () => true);

    // Fallback for relationship status comes from local prefs (guest + signed-in safe).
    final fallbackKey = relationshipStatusKeyFromString('');

    return Scaffold(
      appBar: AppBar(title: const Text('Home'), centerTitle: true),
      body: FutureBuilder<String>(
        future: _loadStatusKeyFromPrefs(),
        builder: (context, statusSnap) {
          final statusKey = statusSnap.data ?? fallbackKey;

          return ListView(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 220 + bottomInset),
            children: [
              if (isGuest)
                Text(
                  'Hello 👋',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                )
              else
                StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, authSnap) {
                    final user =
                        authSnap.data ?? FirebaseAuth.instance.currentUser;
                    return FutureBuilder<String>(
                      future: _homeDisplayNameForUser(user),
                      builder: (context, snap) {
                        final firstName = (snap.data ?? '').trim();
                        return Text(
                          '${_greeting()}, ${firstName.isEmpty ? 'there' : firstName} 👋',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        );
                      },
                    );
                  },
                ),
              const SizedBox(height: 6),
              if (isGuest)
                Text(
                  'You can read our weekly stories without an account!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.75),
                  ),
                )
              else
                Text(
                  'Welcome back — continue where you left off',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.75),
                  ),
                ),
              const SizedBox(height: 14),

              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _assessmentTitleForKey(statusKey),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _assessmentDescForKey(statusKey),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(
                          0.75,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          await GuestGuard.requireSignedIn(
                            context,
                            ref,
                            title: 'Create an account',
                            message:
                                'Create an account to start your assessment and unlock personalized recommendations.',
                            primaryText: 'Create an account',
                            onCreateAccount:
                                () =>
                                    Navigator.of(context).pushNamed('/signup'),
                            onAllowed: () async {
                              Navigator.of(context).pushNamed('/assessment');
                            },
                          );
                        },
                        child: const Text('Start Assessment'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              _StoryOfWeekCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StoriesScreen()),
                  );
                },
              ),

              const SizedBox(height: 16),

              FutureBuilder<String?>(
                future: _loadActiveJourneyIdFromPrefs(),
                builder: (context, activeSnap) {
                  final activeId = activeSnap.data;

                  return Column(
                    children: [
                      if (activeId != null) ...[
                        _JourneyCard(
                          title: 'Continue Journey',
                          subtitle: 'Pick up where you left off',
                          pillText: 'In progress',
                          progress: 0.15,
                          ctaText: 'Continue',
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed('/journey/$activeId');
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      _JourneyCard(
                        title: 'Journeys',
                        subtitle: _journeysCopyForKey(statusKey),
                        pillText: 'New',
                        progress: null,
                        ctaText: 'Start Now',
                        onTap: () async {
                          await GuestGuard.requireSignedIn(
                            context,
                            ref,
                            title: 'Create an account',
                            message:
                                'Create an account to start journeys and unlock personalized guidance.',
                            primaryText: 'Create an account',
                            onCreateAccount:
                                () =>
                                    Navigator.of(context).pushNamed('/signup'),
                            onAllowed: () async {
                              Navigator.of(context).pushNamed('/challenges');
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<Journey>>(
                        future: const JourneyRepository()
                            .loadJourneysForCategory(statusKey),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const SizedBox.shrink();
                          }
                          final list = snapshot.data ?? const <Journey>[];
                          if (list.isEmpty) return const SizedBox.shrink();
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StoryOfWeekCard extends StatelessWidget {
  final VoidCallback onTap;
  const _StoryOfWeekCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const repo = StoryRepository();
    final theme = Theme.of(context);

    return FutureBuilder<Story?>(
      future: repo.loadCurrentStory(),
      builder: (context, snapshot) {
        final story = snapshot.data;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        story?.heroImageAsset ??
                            'assets/images/stories/placeholder_couple.jpg',
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(
                              color: theme.colorScheme.surfaceVariant
                                  .withOpacity(0.5),
                              child: const Center(
                                child: Icon(Icons.image_not_supported_outlined),
                              ),
                            ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.05),
                                Colors.black.withOpacity(0.55),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _GlassPill(text: 'Story of the Week'),
                            const SizedBox(height: 8),
                            Text(
                              story?.title ?? 'Loading story…',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (story != null) ...[
                        Row(
                          children: [
                            _MiniPill(text: story.category),
                            const SizedBox(width: 8),
                            _MiniPill(text: '${story.readTimeMins} min read'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          story.excerpt,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.35,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'A fresh story to guide your dating, marriage, and relationship life this week.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: onTap,
                          child: const Text('Read now'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _JourneyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String pillText;
  final double? progress;
  final String ctaText;
  final VoidCallback onTap;

  const _JourneyCard({
    required this.title,
    required this.subtitle,
    required this.pillText,
    required this.progress,
    required this.ctaText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _MiniPill(text: pillText),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.75),
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: progress),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(onPressed: onTap, child: Text(ctaText)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final String text;
  const _GlassPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String text;
  const _MiniPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: child,
    );
  }
}
