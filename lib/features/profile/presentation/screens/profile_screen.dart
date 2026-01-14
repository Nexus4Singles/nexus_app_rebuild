import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import '../../../launch/presentation/app_launch_gate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/user/is_admin_provider.dart';
import 'package:nexus_app_min_test/features/admin_review/presentation/screens/admin_review_queue_screen.dart';
import 'package:nexus_app_min_test/core/providers/auth_provider.dart';
import 'package:nexus_app_min_test/core/theme/app_colors.dart';
import 'package:nexus_app_min_test/core/theme/app_text_styles.dart';
import 'package:nexus_app_min_test/core/constants/app_constants.dart';
import 'package:nexus_app_min_test/core/session/effective_relationship_status_provider.dart';
import 'package:nexus_app_min_test/core/user/dating_profile_completed_provider.dart';
import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';
import 'package:nexus_app_min_test/core/moderation/moderation_models.dart';
import 'package:nexus_app_min_test/core/moderation/moderation_providers.dart';

import '../../../../core/models/user_model.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:nexus_app_min_test/core/services/media_service.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';
import '../../../../core/user/dating_opt_in_provider.dart';

Future<void> handleLogout(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('Log out?'),
          content: const Text('You will be signed out of your account.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Log out'),
            ),
          ],
        ),
  );

  if (ok != true) return;

  await ref.read(authNotifierProvider.notifier).signOut();
  if (!context.mounted) return;

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const AppLaunchGate()),
    (_) => false,
  );
}

Future<void> handleToggleDatingOptIn(
  BuildContext context,
  WidgetRef ref, {
  required bool nextValue,
}) async {
  final fs = ref.read(firestoreInstanceProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (fs == null || uid == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to update dating settings right now.'),
      ),
    );
    return;
  }

  try {
    await fs.collection('users').doc(uid).set({
      'dating': {'optIn': nextValue},
    }, SetOptions(merge: true));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nextValue ? 'Dating turned on ✅' : 'Dating turned off ✅'),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to update dating settings. Please try again.'),
      ),
    );
  }
}

/// ------------------------------
/// ONBOARDING LISTS LOADER (Assets)
/// ------------------------------
class _OnboardingListsCache {
  static Map<String, dynamic>? _cached;

  static Future<Map<String, dynamic>> load(BuildContext context) async {
    if (_cached != null) return _cached!;
    final raw = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/data/nexus1_onboarding_lists.v1.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _cached = decoded['lists'] as Map<String, dynamic>;
    return _cached!;
  }

  static Future<List<String>> loadChurches(BuildContext context) async {
    final raw = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/data/churches_v1.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final churches =
        (decoded['churches'] as List).map((e) => e.toString()).toList();
    churches.sort();
    return churches;
  }
}

/// ProfileScreen supports:
/// - Viewing your own profile (userId == null)
/// - Viewing another user's profile (userId != null)
///
/// NOTE: Firebase is connected. This screen may still use local draft/mock fallbacks in places
/// while the Firestore-backed profile model is being completed.
class ProfileScreen extends ConsumerWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  bool get isViewingOtherUser => userId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final me = authAsync.maybeWhen(data: (u) => u, orElse: () => null);

    final isSignedIn = me != null;
    // Guard: guests cannot view || edit dating profiles.
    // Debug-only bypass allows UI testing without accounts (release builds unaffected).
    // TEMP: bypass guest gate for UI testing until auth/firebase is connected
    if (!isSignedIn) {
      return _GuestProfileGate(
        onCreateAccount: () => Navigator.of(context).pushNamed('/signup'),
      );
    }

    final effectiveUid = userId ?? me.uid;

    // In Phase 1, we use mock profile data for both own && other profiles.
    final draftAsync = ref.watch(_draftProfileProvider(effectiveUid));
    final mockAsync = ref.watch(_mockProfileProvider(effectiveUid));

    // Draft takes precedence when available; otherwise fallback to mock.
    final profileAsync = draftAsync.when(
      data: (draft) => draft != null ? AsyncValue.data(draft) : mockAsync,
      loading: () => const AsyncValue.loading(),
      error: (_, __) => mockAsync,
    );

    return profileAsync.when(
      loading: () => const _ProfileLoading(),
      error:
          (e, st) => _ProfileError(
            message: 'Unable to load profile right now.',
            onRetry: () => ref.invalidate(_mockProfileProvider(effectiveUid)),
          ),
      data: (profile) {
        if (profile == null) {
          return const _ProfileNotFound();
        }

        final status = ref.watch(effectiveRelationshipStatusProvider);
        final isMarried = status == RelationshipStatus.married;

        // Dating profile completion (v2 flag): users/{uid}.dating.profileCompleted == true
        final datingCompletedAsync = ref.watch(datingProfileCompletedProvider);
        final datingCompleted = datingCompletedAsync.maybeWhen(
          data: (v) => v,
          orElse: () => false,
        );

        // Married users should not see dating profile UI
        if (isMarried) {
          return _BasicProfileScreen(
            profile: profile,
            ref: ref,
            messageTitle: 'Your Profile',
            messageBody:
                'Your account is set to married. Dating is unavailable, but you can still use journeys, stories, polls, and your account settings here.',
            showCreateDatingProfileCta: false,
            onCreateDatingProfile: null,
          );
        }

        final datingOptInAsync = ref.watch(datingOptInProvider);
        final datingOptIn = datingOptInAsync.maybeWhen(
          data: (v) => v,
          orElse: () => true,
        );

        // Users can opt out of dating. They should see a basic profile with no dating UI.
        if (!datingOptIn) {
          return _BasicProfileScreen(
            profile: profile,
            ref: ref,
            messageTitle: 'Your Profile',
            messageBody:
                'Dating is turned off for your account. You can still use journeys, stories, polls, and settings.',
            showCreateDatingProfileCta: false,
            onCreateDatingProfile: null,
          );
        }

        // Eligible users without a dating profile:
        // - If viewing another user -> gate access
        // - If viewing own profile -> show basic profile + CTA to create dating profile
        if (!datingCompleted) {
          if (isViewingOtherUser) {
            return _DatingProfileRequiredGate(
              onCreateDatingProfile: () {
                Navigator.of(context).pushNamed('/dating/setup/age');
              },
            );
          }

          return _BasicProfileScreen(
            profile: profile,
            ref: ref,
            messageTitle: 'Create your dating profile',
            messageBody:
                'You can use Nexus without dating, but you need a dating profile to view other users in the pool and to appear in Search.',
            showCreateDatingProfileCta: true,
            onCreateDatingProfile: () {
              Navigator.of(context).pushNamed('/dating/setup/age');
            },
          );
        }

        if (profile == null) {
          return const _ProfileNotFound();
        }

        final photos = _combineProfileUrlAndPhotos(
          profile.profileUrl,
          profile.photos,
        );
        final location = _buildLocation(profile.city, profile.country);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _AdminReviewEntry()),
              _ProfileHeroAppBar(
                profile: profile,
                photos: photos,
                isViewingOtherUser: isViewingOtherUser,
                canEditRelationshipStatus:
                    (me.uid == profile.id) && !isViewingOtherUser,
                locationText: location,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PrimaryInfo(profile: profile, locationText: location),
                      const SizedBox(height: 18),

                      _QuickChips(profile: profile),
                      const SizedBox(height: 22),

                      _Section(
                        title: 'About',
                        child: _AboutSection(profile: profile),
                      ),
                      const SizedBox(height: 20),

                      _Section(
                        title: 'Hobbies / Interests',
                        child: _RedChipWrap(
                          chips: _parseChipList(profile.hobbies),
                          emptyText: 'No hobbies added yet.',
                        ),
                      ),
                      const SizedBox(height: 20),

                      _Section(
                        title: 'Most Desired Qualities',
                        child: _RedChipWrap(
                          chips: _parseChipList(profile.desiredQualities),
                          emptyText: 'No desired qualities added yet.',
                        ),
                      ),
                      const SizedBox(height: 22),

                      _Section(
                        title: 'Audio Prompts',
                        subtitle:
                            isViewingOtherUser
                                ? 'Listen to their responses'
                                : 'Audio recordings cannot be changed after profile creation',
                        child: _AudioPromptsSection(
                          audioUrls: profile.audioPrompts ?? const [],
                          isLocked: false,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _PremiumActionsRow(
                        isViewingOtherUser: isViewingOtherUser,
                      ),
                      const SizedBox(height: 24),

                      _Section(
                        title: 'Gallery',
                        child: _GalleryGrid(photos: photos),
                      ),
                      const SizedBox(height: 24),

                      if (!isViewingOtherUser) ...[
                        Text('Your Account', style: AppTextStyles.titleLarge),
                        const SizedBox(height: 12),
                        _AccountTiles(context, ref, profile),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ------------------------------
/// BASIC PROFILE (Non-singles)
/// ------------------------------
class _BasicProfileScreen extends StatelessWidget {
  final WidgetRef ref;
  final UserModel profile;
  final String messageTitle;
  final String messageBody;
  final bool showCreateDatingProfileCta;
  final VoidCallback? onCreateDatingProfile;
  const _BasicProfileScreen({
    required this.profile,
    required this.ref,
    required this.messageTitle,
    required this.messageBody,
    required this.showCreateDatingProfileCta,
    required this.onCreateDatingProfile,
  });
  @override
  Widget build(BuildContext context) {
    final p = profile;
    final name = (p.name ?? 'User').trim();
    final email = (p.email ?? '').trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Profile', style: AppTextStyles.titleLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  _InitialsAvatar(name: name),
                  const SizedBox(width: 46),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppTextStyles.titleLarge),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(messageTitle, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    messageBody,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (showCreateDatingProfileCta) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onCreateDatingProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Create a Profile',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text('Your Account', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            _AccountTiles(context, ref, p),
            const SizedBox(height: 18),

            const Spacer(),
            _ProfileTile(
              icon: Icons.logout_rounded,
              title: 'Log out',
              subtitle: 'Sign out of your account',
              onTap: () => _showComingSoon(context, 'Log out'),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

/// ------------------------------
/// MOCK DATA PROVIDER (Phase 1)
/// ------------------------------
/// Replace this with Firestore-backed provider when firebase is ready.
final _mockProfileProvider = FutureProvider.family<UserModel?, String>((
  ref,
  uid,
) async {
  await Future<void>.delayed(const Duration(milliseconds: 600));

  // Deterministic mock values per uid
  final seed = uid.hashCode;
  final rng = Random(seed);

  final photos = List.generate(
    3 + rng.nextInt(2),
    (i) => 'https://picsum.photos/seed/${seed + i}/800/1100',
  );

  return UserModel(
    id: uid,
    name: rng.nextBool() ? 'Ayodele' : 'Tomiwa',
    age: 25 + rng.nextInt(10),
    city: rng.nextBool() ? 'Berlin' : 'Lagos',
    country: rng.nextBool() ? 'Germany' : 'Nigeria',
    profileUrl: photos.first,
    photos: photos,
    hobbies: [
      'Music',
      'Travel',
      'Wine',
      'Books',
      'Writing',
    ].sublist(0, min(5, 3 + rng.nextInt(3))),
    desiredQualities: 'Empathy, Thoughtfulness, Intelligence, Self-control',
    profession: rng.nextBool() ? 'Lawyer' : 'Product Manager',
    educationLevel: rng.nextBool() ? 'Doctorate Degree' : 'Bachelors Degree',
    nationality: rng.nextBool() ? 'Nigerian' : 'Ghanaian',
    stateOfOrigin: null,
    churchName: rng.nextBool() ? 'CAC' : 'Redeemed',
    onPremium: rng.nextBool(),
    // Mock only; Firestore-driven verification status is used for badges.
    isVerified: true,
    audioPrompts: const [
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    ],
  );
});

/// ------------------------------
/// LOCAL DRAFT CACHE (Phase 2A)
/// ------------------------------
/// This enables profile edits to persist locally (SharedPreferences) until Firebase is connected.
/// Draft profile takes precedence over mock data.
String _draftProfileKey(String uid) => 'nexus_profile_draft_$uid';

Future<UserModel?> _loadDraftProfile(String uid) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftProfileKey(uid));
    if (raw == null || raw.isEmpty) return null;
    final map = jsonDecode(raw);
    if (map is! Map<String, dynamic>) return null;
    return UserModel.fromMap(uid, map);
  } catch (_) {
    return null;
  }
}

Future<Map<String, String>> _loadDraftContact(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('draft_profile_' + uid);
  if (raw == null) return {};
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final contact = decoded['draftContact'] as Map<String, dynamic>?;
    if (contact == null) return {};
    return contact.map((k, v) => MapEntry(k, (v ?? '').toString()));
  } catch (_) {
    return {};
  }
}

/// ------------------------------
/// RELATIONSHIP STATUS TAG (SAFE MODE - LOCAL)
/// ------------------------------
enum RelationshipStatusTag { available, taken }

String _relationshipStatusLabel(RelationshipStatusTag v) {
  switch (v) {
    case RelationshipStatusTag.available:
      return 'Available';
    case RelationshipStatusTag.taken:
      return 'Taken';
  }
}

String _relationshipStatusKey(String uid) => 'relationship_status_tag_' + uid;

Future<RelationshipStatusTag> _loadRelationshipStatusTag(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_relationshipStatusKey(uid));
  if (raw == 'taken') return RelationshipStatusTag.taken;
  return RelationshipStatusTag.available;
}

Future<void> _saveRelationshipStatusTag(
  String uid,
  RelationshipStatusTag v,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _relationshipStatusKey(uid),
    v == RelationshipStatusTag.taken ? 'taken' : 'available',
  );
}

class _RelationshipStatusTagController
    extends StateNotifier<AsyncValue<RelationshipStatusTag>> {
  final String uid;

  _RelationshipStatusTagController(this.uid)
    : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await _loadRelationshipStatusTag(uid);
      state = AsyncValue.data(v);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setTag(RelationshipStatusTag v) async {
    // Optimistic update for instant UI feedback.
    state = AsyncValue.data(v);
    try {
      await _saveRelationshipStatusTag(uid, v);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final _relationshipStatusTagProvider = StateNotifierProvider.family<
  _RelationshipStatusTagController,
  AsyncValue<RelationshipStatusTag>,
  String
>((ref, uid) {
  return _RelationshipStatusTagController(uid);
});

class _RelationshipStatusPill extends StatelessWidget {
  final RelationshipStatusTag value;
  final VoidCallback? onTap;

  const _RelationshipStatusPill({required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = _relationshipStatusLabel(value);
    final canTap = onTap != null;

    return Semantics(
      button: canTap,
      label: canTap ? 'Edit dating status' : 'Dating Status',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: canTap ? 14 : 12,
            vertical: canTap ? 10 : 8,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(canTap ? 0.56 : 0.42),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(canTap ? 0.65 : 0.35),
            ),
            boxShadow:
                canTap
                    ? [
                      BoxShadow(
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                        color: Colors.black.withOpacity(0.22),
                      ),
                    ]
                    : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 7,
                width: 7,
                decoration: BoxDecoration(
                  color:
                      value == RelationshipStatusTag.available
                          ? Colors.greenAccent.withOpacity(0.9)
                          : Colors.redAccent.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Dating Status:',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (canTap) ...[
                const SizedBox(width: 10),
                Container(
                  height: 28,
                  width: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.6)),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: Colors.white.withOpacity(0.95),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.background : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _saveDraftProfile(UserModel profile) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(profile.toMap());
    await prefs.setString(_draftProfileKey(profile.id), raw);
  } catch (_) {
    // ignore - local cache best-effort
  }
}

final _draftProfileProvider =
    AsyncNotifierProviderFamily<_DraftProfileController, UserModel?, String>(
      _DraftProfileController.new,
    );

class _DraftProfileController extends FamilyAsyncNotifier<UserModel?, String> {
  @override
  FutureOr<UserModel?> build(String uid) async {
    return await _loadDraftProfile(uid);
  }

  Future<void> setDraft(UserModel profile) async {
    state = AsyncData(profile);
    await _saveDraftProfile(profile);
  }
}

/// ------------------------------
/// HERO APP BAR
/// ------------------------------
class _ProfileHeroAppBar extends StatelessWidget {
  final UserModel profile;
  final List<String> photos;
  final bool isViewingOtherUser;
  final String locationText;
  final bool canEditRelationshipStatus;
  const _ProfileHeroAppBar({
    required this.profile,
    required this.photos,
    required this.isViewingOtherUser,
    required this.locationText,
    required this.canEditRelationshipStatus,
  });
  @override
  Widget build(BuildContext context) {
    final name = profile.name ?? 'User';
    final age = profile.age;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.background,
      expandedHeight: 420,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        if (isViewingOtherUser) _OverflowMenu(targetUid: profile.id),
        const SizedBox(width: 46),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          return FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: _HeroCarousel(
              photos: photos,
              overlayChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  age != null ? '$name, $age' : name,
                                  style: AppTextStyles.headlineLarge.copyWith(
                                    color: Colors.white,
                                    fontSize: 32,
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Consumer(
                                builder: (context, ref, _) {
                                  final statusAsync = ref.watch(
                                    _verificationStatusProvider(profile.id),
                                  );
                                  final status = statusAsync.maybeWhen(
                                    data: (v) => v,
                                    orElse: () => null,
                                  );

                                  // Legacy v1 users may have null/missing status; treat as verified
                                  // so they remain seamless/visible until they explicitly re-verify.
                                  final resolvedStatus =
                                      (status == null || status.isEmpty)
                                          ? 'verified'
                                          : status;

                                  final isVerified =
                                      resolvedStatus == 'verified';
                                  final isPending = resolvedStatus == 'pending';
                                  final isRejected =
                                      resolvedStatus == 'rejected';

                                  // Product nuance:
                                  // - Always show "Verified" badge to others (and self).
                                  // - Only show "Pending review" / "Not verified" to self (avoid exposing moderation state).
                                  if (!isViewingOtherUser) {
                                    if (!(isVerified ||
                                        isPending ||
                                        isRejected)) {
                                      return const SizedBox.shrink();
                                    }
                                  } else {
                                    if (!isVerified)
                                      return const SizedBox.shrink();
                                  }

                                  IconData icon;
                                  String label;
                                  if (isVerified) {
                                    icon = Icons.verified_rounded;
                                    label = 'Verified';
                                  } else if (isPending) {
                                    icon = Icons.hourglass_top_rounded;
                                    label = 'Pending review';
                                  } else {
                                    icon = Icons.block_rounded;
                                    label = 'Not verified';
                                  }

                                  return Row(
                                    children: [
                                      const SizedBox(width: 12),
                                      _Badge(icon: icon, label: label),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  locationText,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.white70,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 14,
                      right: 12,
                      child: Consumer(
                        builder: (context, ref, _) {
                          final tagAsync = ref.watch(
                            _relationshipStatusTagProvider(profile.id),
                          );
                          final value = tagAsync.maybeWhen(
                            data: (v) => v,
                            orElse: () => RelationshipStatusTag.available,
                          );

                          final canEdit = canEditRelationshipStatus;

                          return _RelationshipStatusPill(
                            value: value,
                            onTap:
                                canEdit
                                    ? () async {
                                      final selected = await showModalBottomSheet<
                                        RelationshipStatusTag
                                      >(
                                        context: context,
                                        backgroundColor: Colors.transparent,
                                        isScrollControlled: false,
                                        builder: (sheetContext) {
                                          RelationshipStatusTag temp = value;

                                          return StatefulBuilder(
                                            builder: (
                                              sheetContext,
                                              setSheetState,
                                            ) {
                                              return Container(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      16,
                                                      16,
                                                      16,
                                                      24,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surface,
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            'Relationship status',
                                                            style: AppTextStyles
                                                                .titleLarge
                                                                .copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                ),
                                                          ),
                                                        ),
                                                        InkWell(
                                                          onTap:
                                                              () =>
                                                                  Navigator.pop(
                                                                    sheetContext,
                                                                    null,
                                                                  ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                          child: Container(
                                                            height: 36,
                                                            width: 36,
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  AppColors
                                                                      .background,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    999,
                                                                  ),
                                                              border: Border.all(
                                                                color:
                                                                    AppColors
                                                                        .border,
                                                              ),
                                                            ),
                                                            child: const Icon(
                                                              Icons
                                                                  .close_rounded,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      'Tap to update your visibility on the dating side of the app.',
                                                      style: AppTextStyles
                                                          .bodySmall
                                                          .copyWith(
                                                            color:
                                                                AppColors
                                                                    .textSecondary,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 14),
                                                    _StatusOptionTile(
                                                      label: 'Available',
                                                      selected:
                                                          temp ==
                                                          RelationshipStatusTag
                                                              .available,
                                                      onTap: () {
                                                        handleLogout(
                                                          context,
                                                          ref,
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(height: 10),
                                                    _StatusOptionTile(
                                                      label: 'Taken',
                                                      selected:
                                                          temp ==
                                                          RelationshipStatusTag
                                                              .taken,
                                                      onTap: () {
                                                        setSheetState(() {
                                                          temp =
                                                              RelationshipStatusTag
                                                                  .taken;
                                                        });
                                                        Navigator.pop(
                                                          sheetContext,
                                                          RelationshipStatusTag
                                                              .taken,
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      );

                                      if (selected == null) return;

                                      await ref
                                          .read(
                                            _relationshipStatusTagProvider(
                                              profile.id,
                                            ).notifier,
                                          )
                                          .setTag(selected);
                                    }
                                    : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroCarousel extends StatefulWidget {
  final List<String> photos;
  final Widget overlayChild;
  const _HeroCarousel({required this.photos, required this.overlayChild});

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos.isEmpty ? [''] : widget.photos;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: photos.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) {
            final url = photos[i];
            return Container(
              color: Colors.black,
              child:
                  url.isEmpty
                      ? _InitialsAvatar(name: 'User')
                      : Image.network(url, fit: BoxFit.cover),
            );
          },
        ),
        // gradient overlay for readability
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black54, Colors.transparent, Colors.black87],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
        widget.overlayChild,
        if (photos.length > 1)
          Positioned(
            bottom: 10,
            left: 16,
            right: 16,
            child: _DotsIndicator(count: photos.length, index: _index),
          ),
      ],
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int index;
  const _DotsIndicator({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final isActive = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(right: 6),
          height: 6,
          width: isActive ? 18 : 6,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white30,
            borderRadius: BorderRadius.circular(50),
          ),
        );
      }),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 46),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _OverflowMenu extends ConsumerWidget {
  final String targetUid;
  const _OverflowMenu({required this.targetUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final me = authAsync.maybeWhen(data: (u) => u, orElse: () => null);

    // Phase 1 local-only viewer identity:
    // - signed-in: uid
    // - guest/safe mode: 'guest'
    final viewerKey = (me?.uid ?? 'guest').trim();

    final isBlocked = ref.watch(
      isBlockedProvider((viewerKey: viewerKey, targetUid: targetUid)),
    );

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
      color: AppColors.surface,
      onSelected: (v) async {
        if (v == 'block') {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: const Text('Block user?'),
                content: const Text(
                  'They will be hidden from you and you won’t be able to start a chat with them.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Block'),
                  ),
                ],
              );
            },
          );

          if (ok == true) {
            await ref
                .read(blockedUsersProvider(viewerKey).notifier)
                .block(targetUid);
            _toast(context, 'User blocked');
          }
        } else if (v == 'unblock') {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: const Text('Unblock user?'),
                content: const Text('They will be visible to you again.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Unblock'),
                  ),
                ],
              );
            },
          );

          if (ok == true) {
            await ref
                .read(blockedUsersProvider(viewerKey).notifier)
                .unblock(targetUid);
            _toast(context, 'User unblocked');
          }
        } else if (v == 'report') {
          await _showReportSheet(
            context: context,
            ref: ref,
            reporterKey: viewerKey,
            reportedUid: targetUid,
          );
        }
      },
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: isBlocked ? 'unblock' : 'block',
              child: Text(isBlocked ? 'Unblock User' : 'Block User'),
            ),
            const PopupMenuItem(value: 'report', child: Text('Report User')),
          ],
    );
  }
}

Future<void> _showReportSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String reporterKey,
  required String reportedUid,
}) async {
  ReportReason reason = ReportReason.harassment;
  final notesController = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Report user',
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(sheetContext).pop(),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          height: 36,
                          width: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Reason',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ReportReason>(
                        value: reason,
                        isExpanded: true,
                        items:
                            ReportReason.values
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r.label),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => reason = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Notes (optional)',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Add more details (optional)',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await submitLocalReport(
                            ref: ref,
                            reporterKey: reporterKey,
                            reportedUid: reportedUid,
                            reason: reason,
                            notes: notesController.text,
                          );
                          if (context.mounted) {
                            Navigator.of(sheetContext).pop();
                            _toast(context, 'Report submitted');
                          }
                        } catch (_) {
                          if (context.mounted) {
                            _toast(context, 'Unable to submit report');
                          }
                        }
                      },
                      child: const Text('Submit report'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reports are reviewed. Please avoid sharing sensitive personal information.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  notesController.dispose();
}

/// ------------------------------
/// PRIMARY INFO + QUICK CHIPS
/// ------------------------------
class _PrimaryInfo extends StatelessWidget {
  final UserModel profile;
  final String locationText;
  const _PrimaryInfo({required this.profile, required this.locationText});

  @override
  Widget build(BuildContext context) {
    final about = profile.bestQualitiesOrTraits?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (about != null && about.isNotEmpty) ...[
          Text(about, style: AppTextStyles.bodyLarge),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _QuickChips extends StatelessWidget {
  final UserModel profile;
  const _QuickChips({required this.profile});

  @override
  Widget build(BuildContext context) {
    final chips =
        <String>[
          if ((profile.educationLevel ?? '').trim().isNotEmpty)
            profile.educationLevel!,
          if ((profile.profession ?? '').trim().isNotEmpty) profile.profession!,
          if ((profile.churchName ?? '').trim().isNotEmpty) profile.churchName!,
          if ((profile.nationality ?? '').trim().isNotEmpty)
            profile.nationality!,
        ].where((e) => e.trim().isNotEmpty).toList();

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(c, style: AppTextStyles.bodySmall),
          ),
      ],
    );
  }
}

/// ------------------------------
/// SECTIONS
/// ------------------------------
class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Section({required this.title, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final UserModel profile;
  const _AboutSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final rows = <_AboutRow>[
      _AboutRow('Nationality', profile.nationality),
      _AboutRow('Education Level', profile.educationLevel),
      _AboutRow('Profession/Industry', profile.profession),
      _AboutRow('Church', profile.churchName),
    ];

    final items = rows.where((r) => (r.value ?? '').trim().isNotEmpty).toList();
    if (items.isEmpty) {
      return Text(
        'No information added yet.',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _AboutRowTile(label: items[i].label, value: items[i].value!),
          if (i != items.length - 1)
            const Divider(height: 18, color: AppColors.border),
        ],
      ],
    );
  }
}

class _AboutRow {
  final String label;
  final String? value;
  _AboutRow(this.label, this.value);
}

class _AboutRowTile extends StatelessWidget {
  const _AboutRowTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ------------------------------
class _RedChipWrap extends StatelessWidget {
  final List<String> chips;
  final String emptyText;
  const _RedChipWrap({required this.chips, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) {
      return Text(
        emptyText,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 10,
        children: [
          for (final c in chips)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.82),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.primary.withOpacity(0.82)),
              ),
              child: Text(
                c,
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

/// AUDIO PLACEHOLDER
/// ------------------------------

/// ------------------------------
/// AUDIO (Real playback, one at a time)
/// ------------------------------
final _profileAudioControllerProvider =
    Provider.autoDispose<_ProfileAudioController>((ref) {
      final controller = _ProfileAudioController();
      ref.onDispose(controller.dispose);
      return controller;
    });

class _ProfileAudioController {
  final AudioPlayer _player = AudioPlayer();
  String? currentUrl;

  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  PlayerState state = PlayerState.stopped;

  bool _initialized = false;

  Future<void> init(VoidCallback notify) async {
    if (_initialized) return;
    _initialized = true;

    _player.onDurationChanged.listen((d) {
      duration = d;
      notify();
    });

    _player.onPositionChanged.listen((p) {
      position = p;
      notify();
    });

    _player.onPlayerStateChanged.listen((s) {
      state = s;
      notify();
    });
  }

  Future<void> playOrPause(String url) async {
    if (currentUrl != url) {
      currentUrl = url;
      position = Duration.zero;
      await _player.stop();
      await _player.play(UrlSource(url));
      return;
    }

    if (state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> seek(Duration d) async {
    await _player.seek(d);
  }

  Future<void> stop() async {
    currentUrl = null;
    position = Duration.zero;
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}

class _AudioPromptsSection extends ConsumerStatefulWidget {
  final List<String> audioUrls;
  final bool isLocked;

  const _AudioPromptsSection({required this.audioUrls, required this.isLocked});

  @override
  ConsumerState<_AudioPromptsSection> createState() =>
      _AudioPromptsSectionState();
}

class _AudioPromptsSectionState extends ConsumerState<_AudioPromptsSection> {
  late final _ProfileAudioController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(_profileAudioControllerProvider);
    _controller.init(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final prompts = const [
      'My relationship with God',
      'My view on gender roles in marriage',
      'Favourite qualities || traits about myself',
    ];

    final urls = widget.audioUrls.where((e) => e.trim().isNotEmpty).toList();
    if (urls.isEmpty) {
      return Text(
        'No audio recordings available yet.',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }

    return Column(
      children: List.generate(3, (i) {
        final url = i < urls.length ? urls[i] : null;
        return Padding(
          padding: EdgeInsets.only(bottom: i == 2 ? 0 : 12),
          child: _AudioPromptTile(
            prompt: prompts[i],
            url: url,
            isLocked: widget.isLocked,
            controller: _controller,
          ),
        );
      }),
    );
  }
}

class _AudioPromptTile extends StatelessWidget {
  final String prompt;
  final String? url;
  final bool isLocked;
  final _ProfileAudioController controller;

  const _AudioPromptTile({
    required this.prompt,
    required this.url,
    required this.isLocked,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = (url ?? '').trim().isNotEmpty;
    final isCurrent = hasUrl && controller.currentUrl == url;
    final isPlaying = isCurrent && controller.state == PlayerState.playing;

    final duration =
        controller.duration.inMilliseconds == 0
            ? const Duration(seconds: 1)
            : controller.duration;
    final position = controller.position;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap:
                    (!isLocked && hasUrl)
                        ? () async {
                          await controller.playOrPause(url!);
                        }
                        : null,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    isLocked
                        ? Icons.lock_rounded
                        : hasUrl
                        ? (isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded)
                        : Icons.mic_off_rounded,
                    color:
                        isLocked ? AppColors.textSecondary : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prompt, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      isLocked
                          ? 'Audio recordings cannot be changed after profile creation'
                          : hasUrl
                          ? (isPlaying ? 'Playing…' : 'Tap to play')
                          : 'Not recorded yet',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isLocked && hasUrl) ...[
            const SizedBox(height: 12),
            Slider(
              value:
                  isCurrent
                      ? position.inMilliseconds
                          .clamp(0, duration.inMilliseconds)
                          .toDouble()
                      : 0,
              max: duration.inMilliseconds.toDouble(),
              onChanged: (v) async {
                if (!isCurrent) return;
                await controller.seek(Duration(milliseconds: v.toInt()));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(isCurrent ? position : Duration.zero),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _formatDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final m = two(d.inMinutes.remainder(60));
  final s = two(d.inSeconds.remainder(60));
  return '$m:$s';
}

/// ------------------------------
/// PREMIUM GATED BUTTONS
/// ------------------------------
class _PremiumActionsRow extends StatelessWidget {
  final bool isViewingOtherUser;
  const _PremiumActionsRow({required this.isViewingOtherUser});

  @override
  Widget build(BuildContext context) {
    if (!isViewingOtherUser) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: _PremiumButton(
            icon: Icons.favorite_rounded,
            title: 'Compatibility',
            subtitle: 'Premium only',
            onTap:
                () => _toast(
                  context,
                  'Upgrade to Premium to view compatibility.',
                ),
          ),
        ),
        const SizedBox(width: 46),
        Expanded(
          child: _PremiumButton(
            icon: Icons.chat_bubble_rounded,
            title: 'Contact',
            subtitle: 'Premium only',
            onTap:
                () =>
                    _toast(context, 'Upgrade to Premium to view contact info.'),
          ),
        ),
      ],
    );
  }
}

class _PremiumButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PremiumButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 46,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 46),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.lock_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// ------------------------------
/// GALLERY GRID
/// ------------------------------
class _GalleryGrid extends StatelessWidget {
  final List<String> photos;
  const _GalleryGrid({required this.photos});

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Text(
        'No photos added yet.',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }

    final items = photos.take(6).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, i) {
        final url = items[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: Colors.black12,
            child: GestureDetector(
              onTap: () {
                _openPhotoViewer(context, photos: photos, initialIndex: i);
              },
              child: Image.network(url, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}

/// ------------------------------
/// ACCOUNT TILES (Existing behavior)
/// ------------------------------
class _AccountTiles extends StatelessWidget {
  final BuildContext context;
  final WidgetRef ref;
  final UserModel profile;
  const _AccountTiles(this.context, this.ref, this.profile);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProfileTile(
          icon: Icons.edit_outlined,
          title: 'Edit Profile',
          subtitle: 'Update your profile information',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EditProfileScreen(profile: profile),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _ProfileTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Preferences, privacy & support',
          onTap: () {
            Navigator.of(context).pushNamed('/settings');
          },
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 10),
        _ProfileTile(
          icon: Icons.favorite_border_rounded,
          title: 'Dating',
          subtitle: 'Turn dating on or off',
          onTap: () async {
            final current = await ref.read(datingOptInProvider.future);
            if (!context.mounted) return;

            showModalBottomSheet(
              context: context,
              showDragHandle: true,
              builder: (sheetCtx) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dating', style: AppTextStyles.headlineLarge),
                      const SizedBox(height: 8),
                      Text(
                        'If you turn dating off, you won\'t appear in Search and you won\'t be able to view other users in the pool.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      StatefulBuilder(
                        builder: (ctx, setLocal) {
                          var enabled = current;
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  enabled ? 'On' : 'Off',
                                  style: AppTextStyles.titleMedium,
                                ),
                              ),
                              Switch(
                                value: enabled,
                                onChanged: (v) async {
                                  setLocal(() => enabled = v);
                                  Navigator.of(sheetCtx).pop();
                                  await handleToggleDatingOptIn(
                                    context,
                                    ref,
                                    nextValue: v,
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            );
          },
        ),

        _ProfileTile(
          icon: Icons.workspace_premium_outlined,
          title: 'Premium',
          subtitle: 'Upgrade for more features',
          onTap: () {
            _showComingSoon(context, 'Premium');
          },
        ),
        const SizedBox(height: 10),
        _ProfileTile(
          icon: Icons.logout_rounded,
          title: 'Log out',
          subtitle: 'Sign out of your account',
          onTap: () {
            _showComingSoon(context, 'Log out');
          },
        ),
      ],
    );
  }
}

/// ------------------------------
/// DATING PROFILE REQUIRED GATE
/// ------------------------------
class _DatingProfileRequiredGate extends StatelessWidget {
  final VoidCallback onCreateDatingProfile;
  const _DatingProfileRequiredGate({required this.onCreateDatingProfile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Dating Profile Required',
          style: AppTextStyles.headlineLarge,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create your dating profile',
              style: AppTextStyles.headlineLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'You need a dating profile to view other users in the pool.',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onCreateDatingProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Create a Profile',
                style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------------------
/// CREATE DATING PROFILE (Placeholder)
/// ------------------------------
/// This avoids guessing route names. Replace this with your real dating profile
/// onboarding screen once it exists.

/// ------------------------------
/// GUEST GATE
/// ------------------------------
class _GuestProfileGate extends StatelessWidget {
  final VoidCallback onCreateAccount;
  const _GuestProfileGate({required this.onCreateAccount});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Profile', style: AppTextStyles.headlineLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create an account', style: AppTextStyles.headlineLarge),
            const SizedBox(height: 10),
            Text(
              'You’re currently in guest mode. To access dating profiles, create an account && complete your dating profile.',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onCreateAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Create an account',
                style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------------------
/// LOADING / ERROR / NOT FOUND
/// ------------------------------
class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ProfileError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ProfileError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Profile', style: AppTextStyles.headlineLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Something went wrong', style: AppTextStyles.headlineLarge),
            const SizedBox(height: 10),
            Text(
              message,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Retry',
                style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileNotFound extends StatelessWidget {
  const _ProfileNotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Profile', style: AppTextStyles.headlineLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'User not found.',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// ------------------------------
/// SHARED UI
/// ------------------------------
class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                offset: const Offset(0, 6),
                color: Colors.black.withOpacity(0.05),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 46),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 46),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String name;
  const _InitialsAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFromName(name);
    return Center(
      child: CircleAvatar(
        radius: 44,
        backgroundColor: Colors.white10,
        child: Text(
          initials,
          style: AppTextStyles.headlineLarge.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

/// ------------------------------
/// HELPERS (Required)
/// ------------------------------
List<String> _combineProfileUrlAndPhotos(
  String? profileUrl,
  List<String>? photos,
) {
  final list = <String>[];
  void add(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return;
    if (!list.contains(s)) list.add(s);
  }

  add(profileUrl);
  for (final p in (photos ?? const [])) {
    add(p);
  }

  return list;
}

String _buildLocation(String? city, String? country) {
  final c = (city ?? '').trim();
  final k = (country ?? '').trim();
  if (c.isNotEmpty) return k.isNotEmpty ? '$c, $k' : c;
  if (k.isNotEmpty) return k;
  return 'Location not specified';
}

String _initialsFromName(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'U';
  final first = parts.first.characters.first.toUpperCase();
  final second =
      parts.length > 1 ? parts[1].characters.first.toUpperCase() : '';
  return (first + second).trim();
}

List<String> _parseChipList(dynamic value) {
  if (value == null) return [];
  if (value is List) {
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  final s = value.toString().trim();
  if (s.isEmpty) return [];
  final split = s.split(RegExp(r'[\n,]'));
  return split.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

/// ------------------------------
/// FULL SCREEN PHOTO VIEWER (World-class UX)
/// ------------------------------
void _openPhotoViewer(
  BuildContext context, {
  required List<String> photos,
  required int initialIndex,
}) {
  if (photos.isEmpty) return;

  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder:
          (_, __, ___) => _PhotoViewerScreen(
            photos: photos,
            initialIndex: initialIndex.clamp(0, photos.length - 1),
          ),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(opacity: curved, child: child);
      },
    ),
  );
}

class _PhotoViewerScreen extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  const _PhotoViewerScreen({required this.photos, required this.initialIndex});

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final url = photos[i];
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(child: Image.network(url, fit: BoxFit.contain)),
                );
              },
            ),
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ViewerIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      '${_index + 1}/${photos.length}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (photos.length > 1)
              Positioned(
                bottom: 18,
                left: 16,
                right: 16,
                child: Center(
                  child: _DotsIndicator(count: photos.length, index: _index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewerIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ViewerIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 44,
        width: 46,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

/// ------------------------------
/// EDIT PROFILE (Phase 1 - Local UI only, Firebase pending)
/// ------------------------------
class EditProfileScreen extends ConsumerStatefulWidget {
  final UserModel profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _isSaving = false;
  bool _dirty = false;

  late String _name;
  late int? _age;
  late String _city;
  late String _country;
  late String _nationality;
  late String _educationLevel;
  late String _profession;
  late String _churchName;
  late String _desiredQualities;

  late List<String> _photos;
  late List<String> _hobbies;
  late List<String> _qualities;

  late String _instagram;
  late String _twitter;
  late String _whatsapp;
  late String _facebook;
  late String _telegram;
  late String _snapchat;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    final p = widget.profile;
    _name = p.name ?? '';
    _age = p.age;
    _city = p.city ?? '';
    _country = p.country ?? '';
    _nationality = p.nationality ?? '';
    _educationLevel = p.educationLevel ?? '';
    _profession = p.profession ?? '';
    _churchName = p.churchName ?? '';
    _desiredQualities = p.desiredQualities ?? '';

    _photos =
        _combineProfileUrlAndPhotos(p.profileUrl, p.photos).take(4).toList();
    if (_photos.isEmpty && (p.profileUrl ?? '').trim().isNotEmpty) {
      _photos = [p.profileUrl!.trim()];
    }

    _hobbies = _parseChipList(p.hobbies);
    if (_hobbies.length > 5) _hobbies = _hobbies.take(5).toList();

    _qualities = _parseChipList(p.desiredQualities);
    if (_qualities.length > 5) _qualities = _qualities.take(5).toList();

    // Contact defaults from profile
    _instagram = p.instagramUsername ?? '';
    _twitter = p.twitterUsername ?? '';
    _whatsapp =
        p.phoneNumber ?? ''; // WhatsApp stored as phoneNumber on UserModel
    _facebook = p.facebookUsername ?? '';
    _telegram = p.telegramUsername ?? '';
    _snapchat = p.snapchatUsername ?? '';

    // Load locally saved contact draft (if any). This allows edit profile to retain onboarding values pre-firebase.
    _loadDraftContact(p.id).then((draft) {
      if (!mounted) return;
      setState(() {
        _instagram = draft['instagram'] ?? _instagram;
        _twitter = draft['twitter'] ?? _twitter;
        _whatsapp = draft['whatsappNumber'] ?? draft['whatsapp'] ?? _whatsapp;
        _facebook = draft['facebook'] ?? _facebook;
        _telegram = draft['telegram'] ?? _telegram;
        _snapchat = draft['snapchat'] ?? _snapchat;
      });
    });
    _twitter = p.twitterUsername ?? '';
    _facebook = p.facebookUsername ?? '';
    _telegram = p.telegramUsername ?? '';
    _snapchat = p.snapchatUsername ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _confirmExitIfDirty() async {
    if (!_dirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text(
              'You have unsaved changes. If you leave now, they will be lost.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
    );
    return result == true;
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    if (!_dirty) return;
    setState(() => _isSaving = true);

    // Normalize photos: remove duplicates, remove empty, enforce max 4
    final seen = <String>{};
    final cleanPhotos = <String>[];
    for (final p in _photos) {
      final v = p.trim();
      if (v.isEmpty) continue;
      if (seen.add(v)) cleanPhotos.add(v);
      if (cleanPhotos.length == 4) break;
    }

    final updatedProfile = widget.profile.copyWith(
      name: _name.trim().isEmpty ? widget.profile.name : _name.trim(),
      age: _age,
      city: _city.trim(),
      country: _country.trim(),
      nationality: _nationality.trim(),
      educationLevel: _educationLevel.trim(),
      profession: _profession.trim(),
      churchName: _churchName.trim(),
      desiredQualities: _qualities.join(', '),
      hobbies: _hobbies,
      photos: cleanPhotos,
      profileUrl:
          cleanPhotos.isNotEmpty
              ? cleanPhotos.first
              : widget.profile.profileUrl,
      instagramUsername: _instagram.trim(),
      twitterUsername: _twitter.trim(),
      phoneNumber:
          _whatsapp.trim(), // WhatsApp stored as phoneNumber on UserModel
      facebookUsername: _facebook.trim(),
      telegramUsername: _telegram.trim(),
      snapchatUsername: _snapchat.trim(),
    );

    // Persist locally so profile updates immediately (Firebase pending)
    await ref
        .read(_draftProfileProvider(widget.profile.id).notifier)
        .setDraft(updatedProfile);

    // Persist draft contact separately (until UserModel schema is unified)
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('draft_profile_' + widget.profile.id);
    final decoded =
        raw != null
            ? (jsonDecode(raw) as Map<String, dynamic>)
            : <String, dynamic>{};
    decoded['draftContact'] = {
      'instagram': _instagram.trim(),
      'twitter': _twitter.trim(),
      'whatsappNumber': _whatsapp.trim(),
      'facebook': _facebook.trim(),
      'telegram': _telegram.trim(),
      'snapchat': _snapchat.trim(),
    };
    await prefs.setString(
      'draft_profile_' + widget.profile.id,
      jsonEncode(decoded),
    );

    // Small delay to feel responsive
    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _dirty = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved locally (Firebase integration pending).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmExitIfDirty,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text('Edit Profile', style: AppTextStyles.headlineLarge),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () async {
              final ok = await _confirmExitIfDirty();
              if (ok && mounted) Navigator.of(context).pop();
            },
          ),
          actions: [
            if (_dirty)
              TextButton(
                onPressed: _isSaving ? null : _save,
                child:
                    _isSaving
                        ? const SizedBox(
                          height: 18,
                          width: 46,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(
                          'Save',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
              ),
            const SizedBox(width: 46),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Photos'),
              Tab(text: 'About'),
              Tab(text: 'Interests'),
              Tab(text: 'Contact'),
            ],
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                _PhotosEditor(
                  photos: _photos,
                  onMakeProfile: (index) {
                    if (index <= 0 || index >= _photos.length) return;
                    final selected = _photos.removeAt(index);
                    _photos.insert(0, selected);
                    _markDirty();
                    setState(() {});
                  },
                  onDelete: (index) {
                    if (_photos.length <= 1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You cannot delete your last photo.'),
                        ),
                      );
                      return;
                    }
                    _photos.removeAt(index);
                    _markDirty();
                    setState(() {});
                  },
                  onAddPhoto: () async {
                    final service = MediaService();

                    if (_photos.length >= 4) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You can only add up to 4 photos.'),
                        ),
                      );
                      return;
                    }

                    final file = await service.pickImage(context);
                    if (file == null) return;

                    final face = await service.hasHumanFace(file.path);
                    if (face == false) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "We couldn’t detect a human face in that photo. Please upload a clear photo of yourself (good lighting, face visible).",
                          ),
                        ),
                      );
                      return;
                    }

                    if (face == null) {
                      // Fail-open: detection failed technically, but we still educate the user.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "We couldn’t verify this photo automatically, but we added it. Please ensure it’s a clear photo of you.",
                          ),
                        ),
                      );
                    }

                    // fail-open: face == null means detection failed technically; allow photo
                    final path = file.path.trim();
                    if (path.isEmpty) return;
                    if (_photos.contains(path)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('That photo is already added.'),
                        ),
                      );
                      return;
                    }

                    _photos.add(path);
                    if (_photos.length > 4) {
                      _photos = _photos.take(4).toList();
                    }

                    _markDirty();
                    setState(() {});
                  },
                ),
                _AboutEditor(
                  name: _name,
                  age: _age,
                  city: _city,
                  country: _country,
                  nationality: _nationality,
                  educationLevel: _educationLevel,
                  profession: _profession,
                  churchName: _churchName,
                  desiredQualities: _desiredQualities,
                  onChanged: (v) {
                    _name = v.name;
                    _age = v.age;
                    _city = v.city;
                    _country = v.country;
                    _nationality = v.nationality;
                    _educationLevel = v.educationLevel;
                    _profession = v.profession;
                    _churchName = v.churchName;
                    _desiredQualities = v.desiredQualities;
                    _markDirty();
                  },
                ),
                _InterestsEditor(
                  hobbies: _hobbies,
                  qualities: _qualities,
                  onChanged: (h, q) {
                    _hobbies = h;
                    _qualities = q;
                    _markDirty();
                  },
                ),
                _ContactEditor(
                  instagram: _instagram,
                  twitter: _twitter,
                  whatsapp: _whatsapp,
                  facebook: _facebook,
                  telegram: _telegram,
                  snapchat: _snapchat,
                  onChanged: (v) {
                    _instagram = v.instagram;
                    _twitter = v.twitter;
                    _whatsapp = v.whatsapp;
                    _facebook = v.facebook;
                    _telegram = v.telegram;
                    _snapchat = v.snapchat;
                    _markDirty();
                  },
                ),
              ],
            ),
            if (_isSaving)
              Container(
                color: Colors.black.withOpacity(0.2),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotosEditor extends StatelessWidget {
  final List<String> photos;
  final void Function(int index) onMakeProfile;
  final void Function(int index) onDelete;
  final Future<void> Function() onAddPhoto;

  const _PhotosEditor({
    required this.photos,
    required this.onMakeProfile,
    required this.onDelete,
    required this.onAddPhoto,
  });
  @override
  Widget build(BuildContext context) {
    final items = photos.take(4).toList();
    final showAdd = items.length < 4;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Photos', style: AppTextStyles.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Your first photo is your profile photo. Tap a photo to make it your profile photo. You can have up to 4 photos.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              itemCount: showAdd ? items.length + 1 : items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (context, i) {
                if (showAdd && i == items.length) {
                  return _AddPhotoTile(
                    onTap: () {
                      onAddPhoto();
                    },
                  );
                }

                final url = items[i];
                final isProfile = i == 0;

                return GestureDetector(
                  onTap: () => onMakeProfile(i),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          color: Colors.black12,
                          child: _SmartImage(url: url, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isProfile
                                    ? Icons.star_rounded
                                    : Icons.image_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 46),
                              Text(
                                isProfile ? 'Profile' : 'Tap to set',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: InkWell(
                          onTap: () => onDelete(i),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const _SmartImage({required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final value = url.trim();
    if (value.startsWith('http')) {
      return Image.network(
        value,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return Image.file(
      File(value),
      fit: fit,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPhotoTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_a_photo_outlined,
                size: 28,
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              Text('Add photo', style: AppTextStyles.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutEditorValue {
  final String name;
  final int? age;
  final String city;
  final String country;
  final String nationality;
  final String educationLevel;
  final String profession;
  final String churchName;
  final String desiredQualities;

  _AboutEditorValue({
    required this.name,
    required this.age,
    required this.city,
    required this.country,
    required this.nationality,
    required this.educationLevel,
    required this.profession,
    required this.churchName,
    required this.desiredQualities,
  });
}

class _AboutEditor extends StatelessWidget {
  final String name;
  final int? age;
  final String city;
  final String country;
  final String nationality;
  final String educationLevel;
  final String profession;
  final String churchName;
  final String desiredQualities;
  final void Function(_AboutEditorValue value) onChanged;

  const _AboutEditor({
    required this.name,
    required this.age,
    required this.city,
    required this.country,
    required this.nationality,
    required this.educationLevel,
    required this.profession,
    required this.churchName,
    required this.desiredQualities,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InputField(
            label: 'Display name',
            initialValue: name,
            onChanged:
                (v) => onChanged(
                  _AboutEditorValue(
                    name: v,
                    age: age,
                    city: city,
                    country: country,
                    nationality: nationality,
                    educationLevel: educationLevel,
                    profession: profession,
                    churchName: churchName,
                    desiredQualities: desiredQualities,
                  ),
                ),
          ),
          const SizedBox(height: 12),
          _DropdownField(
            label: 'Age',
            value: (age ?? '').toString(),
            items: List.generate(50, (i) => (21 + i).toString()),
            onChanged:
                (v) => onChanged(
                  _AboutEditorValue(
                    name: name,
                    age: int.tryParse(v),
                    city: city,
                    country: country,
                    nationality: nationality,
                    educationLevel: educationLevel,
                    profession: profession,
                    churchName: churchName,
                    desiredQualities: desiredQualities,
                  ),
                ),
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'City',
            initialValue: city,
            onChanged:
                (v) => onChanged(
                  _AboutEditorValue(
                    name: name,
                    age: age,
                    city: v,
                    country: country,
                    nationality: nationality,
                    educationLevel: educationLevel,
                    profession: profession,
                    churchName: churchName,
                    desiredQualities: desiredQualities,
                  ),
                ),
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'Country',
            initialValue: country,
            onChanged:
                (v) => onChanged(
                  _AboutEditorValue(
                    name: name,
                    age: age,
                    city: city,
                    country: v,
                    nationality: nationality,
                    educationLevel: educationLevel,
                    profession: profession,
                    churchName: churchName,
                    desiredQualities: desiredQualities,
                  ),
                ),
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'Nationality',
            initialValue: nationality,
            onChanged:
                (v) => onChanged(
                  _AboutEditorValue(
                    name: name,
                    age: age,
                    city: city,
                    country: country,
                    nationality: v,
                    educationLevel: educationLevel,
                    profession: profession,
                    churchName: churchName,
                    desiredQualities: desiredQualities,
                  ),
                ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: _OnboardingListsCache.load(context),
            builder: (context, snap) {
              final items =
                  (snap.data?['educationalLevels'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  const <String>[];
              return _DropdownField(
                label: 'Education level',
                value: educationLevel,
                items: items,
                onChanged:
                    (v) => onChanged(
                      _AboutEditorValue(
                        name: name,
                        age: age,
                        city: city,
                        country: country,
                        nationality: nationality,
                        educationLevel: v,
                        profession: profession,
                        churchName: churchName,
                        desiredQualities: desiredQualities,
                      ),
                    ),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: _OnboardingListsCache.load(context),
            builder: (context, snap) {
              final items =
                  (snap.data?['professions'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  const <String>[];
              return _DropdownField(
                label: 'Profession',
                value: profession,
                items: items,
                onChanged:
                    (v) => onChanged(
                      _AboutEditorValue(
                        name: name,
                        age: age,
                        city: city,
                        country: country,
                        nationality: nationality,
                        educationLevel: educationLevel,
                        profession: v,
                        churchName: churchName,
                        desiredQualities: desiredQualities,
                      ),
                    ),
              );
            },
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          FutureBuilder<List<String>>(
            future: _OnboardingListsCache.loadChurches(context),
            builder: (context, snap) {
              final churches = snap.data ?? const <String>[];
              final items = ['Other', ...churches];
              final hasChurch = churchName.trim().isNotEmpty;
              final isOther =
                  hasChurch && !churches.contains(churchName.trim());

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DropdownField(
                    label: 'Church (optional)',
                    value: hasChurch ? (isOther ? 'Other' : churchName) : '',
                    items: items,
                    onChanged: (v) {
                      if (v == 'Other') {
                        onChanged(
                          _AboutEditorValue(
                            name: name,
                            age: age,
                            city: city,
                            country: country,
                            nationality: nationality,
                            educationLevel: educationLevel,
                            profession: profession,
                            churchName: '',
                            desiredQualities: desiredQualities,
                          ),
                        );
                      } else {
                        onChanged(
                          _AboutEditorValue(
                            name: name,
                            age: age,
                            city: city,
                            country: country,
                            nationality: nationality,
                            educationLevel: educationLevel,
                            profession: profession,
                            churchName: v,
                            desiredQualities: desiredQualities,
                          ),
                        );
                      }
                    },
                  ),
                  if (isOther)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _InputField(
                        label: 'Enter church name',
                        initialValue: churchName,
                        onChanged:
                            (v) => onChanged(
                              _AboutEditorValue(
                                name: name,
                                age: age,
                                city: city,
                                country: country,
                                nationality: nationality,
                                educationLevel: educationLevel,
                                profession: profession,
                                churchName: v,
                                desiredQualities: desiredQualities,
                              ),
                            ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InterestsEditor extends ConsumerStatefulWidget {
  final List<String> hobbies;
  final List<String> qualities;
  final void Function(List<String> hobbies, List<String> qualities) onChanged;

  const _InterestsEditor({
    required this.hobbies,
    required this.qualities,
    required this.onChanged,
  });
  @override
  ConsumerState<_InterestsEditor> createState() => _InterestsEditorState();
}

class _InterestsEditorState extends ConsumerState<_InterestsEditor> {
  final _hobbySearch = TextEditingController();
  final _qualitySearch = TextEditingController();

  late List<String> _selectedHobbies;
  late List<String> _selectedQualities;

  @override
  void initState() {
    super.initState();
    _selectedHobbies = [...widget.hobbies];
    _selectedQualities = [...widget.qualities];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _OnboardingListsCache.load(context),
      builder: (context, snap) {
        final lists = snap.data ?? const <String, dynamic>{};

        final hobbies =
            (lists['hobbies'] as List?)?.map((e) => e.toString()).toList() ??
            const <String>[];
        final qualities =
            (lists['desireQualities'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];

        final hobbyFilter = _hobbySearch.text.trim().toLowerCase();
        final qualityFilter = _qualitySearch.text.trim().toLowerCase();

        final hobbyItems =
            hobbyFilter.isEmpty
                ? hobbies
                : hobbies
                    .where((h) => h.toLowerCase().contains(hobbyFilter))
                    .toList();

        final qualityItems =
            qualityFilter.isEmpty
                ? qualities
                : qualities
                    .where((q) => q.toLowerCase().contains(qualityFilter))
                    .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hobbies / Interests', style: AppTextStyles.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Select up to 5',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _SearchField(
                controller: _hobbySearch,
                hint: 'Search hobbies',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _SelectableInterestGrid(
                items: hobbyItems,
                selected: _selectedHobbies,
                max: 8,
                onToggle: (v) {
                  setState(() {
                    if (_selectedHobbies.contains(v)) {
                      _selectedHobbies.remove(v);
                    } else {
                      if (_selectedHobbies.length >= 5) {
                        _toast(context, 'You can only select up to 5 hobbies.');
                        return;
                      }
                      _selectedHobbies.add(v);
                    }
                  });
                  widget.onChanged(_selectedHobbies, _selectedQualities);
                },
              ),
              const SizedBox(height: 26),

              Text('Desired Qualities', style: AppTextStyles.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Select up to 8',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _SearchField(
                controller: _qualitySearch,
                hint: 'Search qualities',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _SelectableInterestGrid(
                items: qualityItems,
                selected: _selectedQualities,
                max: 5,
                onToggle: (v) {
                  setState(() {
                    if (_selectedQualities.contains(v)) {
                      _selectedQualities.remove(v);
                    } else {
                      if (_selectedQualities.length >= 8) {
                        _toast(
                          context,
                          'You can only select up to 8 qualities.',
                        );
                        return;
                      }
                      _selectedQualities.add(v);
                    }
                  });
                  widget.onChanged(_selectedHobbies, _selectedQualities);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _SelectableInterestGrid extends StatelessWidget {
  final List<String> items;
  final List<String> selected;
  final int max;
  final ValueChanged<String> onToggle;

  const _SelectableInterestGrid({
    required this.items,
    required this.selected,
    required this.max,
    required this.onToggle,
  });
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 12,
      children: [
        for (final item in items)
          _SelectableChip(
            label: item,
            selected: selected.contains(item),
            onTap: () => onToggle(item),
          ),
      ],
    );
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppColors.primary.withOpacity(0.12)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: selected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ContactEditorValue {
  final String instagram;
  final String twitter;
  final String whatsapp;
  final String facebook;
  final String telegram;
  final String snapchat;

  _ContactEditorValue({
    required this.instagram,
    required this.twitter,
    required this.whatsapp,
    required this.facebook,
    required this.telegram,
    required this.snapchat,
  });
}

class _ContactEditor extends StatelessWidget {
  final String instagram;
  final String twitter;
  final String whatsapp;
  final String facebook;
  final String telegram;
  final String snapchat;
  final void Function(_ContactEditorValue value) onChanged;

  const _ContactEditor({
    required this.instagram,
    required this.twitter,
    required this.whatsapp,
    required this.facebook,
    required this.telegram,
    required this.snapchat,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _InputField(
            label: 'Instagram',
            initialValue: instagram,
            onChanged:
                (v) => onChanged(
                  _ContactEditorValue(
                    instagram: v,
                    twitter: twitter,
                    whatsapp: whatsapp,
                    facebook: facebook,
                    telegram: telegram,
                    snapchat: snapchat,
                  ),
                ),
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'Twitter/X',
            initialValue: twitter,
            onChanged:
                (v) => onChanged(
                  _ContactEditorValue(
                    instagram: instagram,
                    twitter: v,
                    whatsapp: whatsapp,
                    facebook: facebook,
                    telegram: telegram,
                    snapchat: snapchat,
                  ),
                ),
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'WhatsApp',
            initialValue: whatsapp,
            keyboardType: TextInputType.phone,
            onChanged:
                (v) => onChanged(
                  _ContactEditorValue(
                    instagram: instagram,
                    twitter: twitter,
                    whatsapp: v,
                    facebook: facebook,
                    telegram: telegram,
                    snapchat: snapchat,
                  ),
                ),
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'Facebook',
            initialValue: facebook,
            onChanged:
                (v) => onChanged(
                  _ContactEditorValue(
                    instagram: instagram,
                    twitter: twitter,
                    whatsapp: whatsapp,
                    facebook: v,
                    telegram: telegram,
                    snapchat: snapchat,
                  ),
                ),
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'Telegram',
            initialValue: telegram,
            onChanged:
                (v) => onChanged(
                  _ContactEditorValue(
                    instagram: instagram,
                    twitter: twitter,
                    whatsapp: whatsapp,
                    facebook: facebook,
                    telegram: v,
                    snapchat: snapchat,
                  ),
                ),
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'Snapchat',
            initialValue: snapchat,
            onChanged:
                (v) => onChanged(
                  _ContactEditorValue(
                    instagram: instagram,
                    twitter: twitter,
                    whatsapp: whatsapp,
                    facebook: facebook,
                    telegram: telegram,
                    snapchat: v,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final String initialValue;
  final TextInputType? keyboardType;
  final void Function(String value) onChanged;

  const _InputField({
    required this.label,
    required this.initialValue,
    this.keyboardType,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initialValue,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

void _showComingSoon(BuildContext context, String feature) {
  _toast(context, '$feature is coming soon.');
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final normalizedItems = items.toSet().toList();
    normalizedItems.sort();

    final safeValue = normalizedItems.contains(value) ? value : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue.isEmpty ? null : safeValue,
              hint: Text(
                'Select $label',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              items:
                  normalizedItems
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e,
                          child: Text(e, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
              onChanged: (v) {
                if (v == null) return;
                onChanged(v);
              },
              isExpanded: true,
            ),
          ),
        ),
      ],
    );
  }
}

final _verificationStatusProvider = StreamProvider.family<String?, String>((
  ref,
  uid,
) {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  if (!firebaseReady) return Stream.value(null);

  final fs = ref.watch(firestoreInstanceProvider);
  if (fs == null) return Stream.value(null);

  return fs.collection('users').doc(uid).snapshots().map((doc) {
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    final dating = (data['dating'] is Map) ? data['dating'] as Map : null;
    final status = dating?['verificationStatus']?.toString();
    return status;
  });
});

class _AdminReviewEntry extends ConsumerWidget {
  const _AdminReviewEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminReviewQueueScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.black.withOpacity(0.04),
          ),
          child: Row(
            children: const [
              Icon(Icons.admin_panel_settings_rounded),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Admin: Review Pending Profiles',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
