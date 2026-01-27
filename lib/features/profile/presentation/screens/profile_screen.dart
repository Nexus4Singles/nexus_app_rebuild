import 'dart:io';
import 'package:nexus_app_min_test/core/user/current_user_doc_provider.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexus_app_min_test/features/auth/presentation/screens/login_screen.dart';
import 'package:nexus_app_min_test/features/launch/presentation/app_launch_gate.dart';
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
import 'package:nexus_app_min_test/core/bootstrap/bootstrap_gate.dart';
import 'package:nexus_app_min_test/features/guest/guest_entry_gate.dart';
import 'package:nexus_app_min_test/core/providers/service_providers.dart';
import '../../../../core/user/dating_opt_in_provider.dart';
import '../../../subscription/presentation/screens/subscription_screen.dart';

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

  // Navigate to welcome screen with background image
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
final userDocByIdProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((doc) {
            if (!doc.exists) return null;
            return doc.data();
          });
    });

final currentUserIsPremiumProvider = StreamProvider<bool>((ref) {
  return ref.watch(currentUserDocProvider.stream).map((doc) {
    final v = doc?['onPremium'];
    return v == true;
  });
});

class ProfileScreen extends ConsumerWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  bool get isViewingOtherUser => userId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final me = authAsync.maybeWhen(data: (u) => u, orElse: () => null);

    // ignore: avoid_print
    print('[ProfileScreen] BUILD - me=$me, authAsync=$authAsync');

    final isSignedIn = me != null;
    // Guard: guests cannot view || edit dating profiles.
    // Debug-only bypass allows UI testing without accounts (release builds unaffected).
    // TEMP: bypass guest gate for UI testing until auth/firebase is connected
    if (!isSignedIn) {
      // ignore: avoid_print
      print('[ProfileScreen] NOT SIGNED IN');
      return _GuestProfileGate(
        onCreateAccount: () => Navigator.of(context).pushNamed('/signup'),
      );
    }

    final effectiveUid = userId ?? me.uid;

    // Firebase is connected: for signed-in users, Profile must be Firestore-backed.
    // No mock fallback for signed-in paths.
    final userDocAsync =
        isViewingOtherUser
            ? ref.watch(userDocByIdProvider(effectiveUid))
            : ref.watch(currentUserDocProvider);

    // ignore: avoid_print
    print('[ProfileScreen] userDocAsync=$userDocAsync');

    return userDocAsync.when(
      loading: () {
        // ignore: avoid_print
        print('[ProfileScreen] LOADING STATE');
        return const _ProfileLoading();
      },
      error:
          (e, st) => _ProfileError(
            message: 'Unable to load profile right now.',
            onRetry:
                () => ref.invalidate(
                  isViewingOtherUser
                      ? userDocByIdProvider(effectiveUid)
                      : currentUserDocProvider,
                ),
          ),
      data: (map) {
        // If the document is missing for current user (not viewing other user), create minimal profile
        if (map == null && !isViewingOtherUser) {
          // Create a minimal UserModel with just auth data - show basic profile
          final minimalProfile = UserModel.fromMap(me.uid, {
            'uid': me.uid,
            'email': me.email ?? '',
            'schemaVersion': 2,
            'isGuest': false,
            'isAdmin': false,
          });

          return _BasicProfileScreen(
            profile: minimalProfile,
            ref: ref,
            messageTitle: 'Your Profile',
            messageBody:
                'If you would like to join the dating pool of Nexus, create a dating profile to get started.',
            showCreateDatingProfileCta: true,
            onCreateDatingProfile: () {
              Navigator.of(context).pushNamed('/dating/setup/age');
            },
          );
        }

        // For viewing other users with missing docs, show not found
        if (map == null) return const _ProfileNotFound();

        // Debug: Log raw Firestore data to verify photos are present
        debugPrint('📄 Raw Firestore map for user $effectiveUid:');
        debugPrint('  dating.photos: ${map['dating']?['photos']}');
        debugPrint(
          '  dating.profile.photos: ${map['dating']?['profile']?['photos']}',
        );
        debugPrint(
          '  dating.profile.profileUrl: ${map['dating']?['profile']?['profileUrl']}',
        );
        debugPrint('  photos (root): ${map['photos']}');

        // Build a proper UserModel from Firestore data.
        final profile = UserModel.fromMap(effectiveUid, map);

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
                'Your account is set to married. Dating is unavailable, but you can still use journeys, stories, polls, && your account settings here.',
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
                'Dating is turned off for your account. You can still use journeys, stories, polls, && settings.',
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
            messageTitle: 'Dating Profile',
            messageBody:
                'If you would like to join the dating pool, you would need a profile to view opposite gender users in the pool & to appear in Search results.',
            showCreateDatingProfileCta: true,
            onCreateDatingProfile: () {
              Navigator.of(context).pushNamed('/dating/setup/age');
            },
          );
        }

        final photos = _combineProfileUrlAndPhotos(
          profile.profileUrl,
          profile.photos,
        );
        debugPrint(
          '🖼️ Profile photos - profileUrl: "${profile.profileUrl}", photos list: ${profile.photos}',
        );
        debugPrint('🖼️ Combined photos for display: $photos');
        final location = _buildLocation(profile.city, profile.country);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
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
                      const SizedBox(height: 10),

                      if (isViewingOtherUser)
                        _SendMessageCta(profile: profile, viewerUid: me.uid)
                      else
                        _QuickChips(profile: profile),

                      const SizedBox(height: 14),

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
                          isViewingOtherUser: isViewingOtherUser,
                          username: profile.username,
                          gender: profile.gender,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _PremiumActionsRow(
                        isViewingOtherUser: isViewingOtherUser,
                        profile: profile,
                      ),
                      const SizedBox(height: 24),

                      _Section(
                        title: 'Gallery',
                        child: _GalleryGrid(photos: photos),
                      ),
                      const SizedBox(height: 24),

                      if (!isViewingOtherUser) ...[
                        Text('Your Account', style: AppTextStyles.titleLarge),
                        const SizedBox(height: 8),
                        _AccountTiles(
                          context,
                          ref,
                          profile,
                          showEditProfile: true,
                        ),
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
class _BasicProfileScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    final name = (p.name ?? 'User').trim();
    final email = (p.email ?? '').trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            backgroundColor: AppColors.background,
            elevation: 0,
            pinned: true,
            foregroundColor: Colors.white,
            actions: [
              if (kDebugMode)
                IconButton(
                  tooltip: 'Copy Firebase ID token',
                  icon: const Icon(Icons.vpn_key_rounded),
                  onPressed: () async {
                    try {
                      final token = await FirebaseAuth.instance.currentUser
                          ?.getIdToken(true);
                      if (token == null || token.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No ID token found. Please sign in.'),
                          ),
                        );
                        return;
                      }
                      await Clipboard.setData(ClipboardData(text: token));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ID token copied to clipboard.'),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to get token: $e')),
                      );
                    }
                  },
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Stack(
                    children: [
                      // Top title
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Profile',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      // Centered avatar + name
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 44, 24, 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    _initialsFromName(name),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              if (email.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.85),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              collapseMode: CollapseMode.pin,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Message Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.08),
                          AppColors.primary.withOpacity(0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status icon + title
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.info_outline,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                messageTitle,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          messageBody,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        if (showCreateDatingProfileCta) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: onCreateDatingProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Create a Dating Profile',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account Settings Section
                  Text('Your Account', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 8),
                  _AccountTiles(context, ref, p, showEditProfile: false),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ------------------------------
/// MOCK DATA PROVIDER (Phase 1)
/// ------------------------------
/// Replace this with Firestore-backed provider when firebase is ready.

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
  if (raw == null) return <String, String>{};
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final contact = decoded['draftContact'] as Map<String, dynamic>?;
    if (contact == null) return <String, String>{};
    return contact.map((k, v) => MapEntry(k, (v ?? '').toString()));
  } catch (_) {
    return <String, String>{};
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

/// Firestore-backed dating availability status.
/// Stored at: users/{uid}.dating.availability = 'available' | 'taken'
/// Default: 'available' (missing field should not block visibility).
final _relationshipStatusTagProvider =
    StreamProvider.family<RelationshipStatusTag, String>((ref, uid) {
      final fs = FirebaseFirestore.instance;
      return fs.collection('users').doc(uid).snapshots().map((doc) {
        final data = doc.data();
        final dating = (data?['dating'] as Map?)?.cast<String, dynamic>();
        final raw = (dating?['availability'] as String?)?.trim().toLowerCase();

        if (raw == 'taken') return RelationshipStatusTag.taken;
        return RelationshipStatusTag.available;
      });
    });

Future<void> _setRelationshipStatusTagFirestore(
  String uid,
  RelationshipStatusTag v,
) async {
  final key = (v == RelationshipStatusTag.taken) ? 'taken' : 'available';

  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'dating': {'availability': key},
  }, SetOptions(merge: true));
}

class _RelationshipStatusPill extends ConsumerWidget {
  final RelationshipStatusTag value;
  final VoidCallback? onTap;

  const _RelationshipStatusPill({required this.value, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            horizontal: canTap ? 11 : 10,
            vertical: canTap ? 7 : 6,
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
                height: 6,
                width: 6,
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
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (canTap) ...[
                const SizedBox(width: 10),
                Container(
                  height: 22,
                  width: 22,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.6)),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 13,
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
            Flexible(
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
    final name =
        (profile.username ?? '').trim().isNotEmpty
            ? profile.username!.trim()
            : ((profile.name ?? '').trim().isNotEmpty
                ? profile.name!.trim()
                : 'User');
    final age = profile.age;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.background,
      expandedHeight: 420,
      leading:
          isViewingOtherUser
              ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              )
              : null,
      actions: [if (isViewingOtherUser) const SizedBox(width: 12)],
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

                                  // For new profiles (null status), set to pending (awaiting admin review)
                                  // For legacy v1 users with null status after schema migration, also treat as pending
                                  final resolvedStatus =
                                      (status == null || status.isEmpty)
                                          ? 'pending'
                                          : status;

                                  final isVerified =
                                      resolvedStatus == 'verified';
                                  final isPending = resolvedStatus == 'pending';

                                  // Show verification badge for both own and other users
                                  // with accurate status (Verified / Unverified)

                                  IconData icon;
                                  String label;
                                  if (isVerified) {
                                    icon = Icons.verified_rounded;
                                    label = 'Verified';
                                  } else if (isPending) {
                                    icon = Icons.hourglass_top_rounded;
                                    label = 'Unverified';
                                  } else {
                                    icon = Icons.block_rounded;
                                    label = 'Unverified';
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
                      top: 0,
                      right: 0,
                      child: SafeArea(
                        minimum: const EdgeInsets.only(top: 6, right: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Consumer(
                              builder: (context, ref, _) {
                                final tagAsync = ref.watch(
                                  _relationshipStatusTagProvider(profile.id),
                                );
                                final value = tagAsync.maybeWhen(
                                  data: (v) => v,
                                  orElse: () => RelationshipStatusTag.available,
                                );

                                final canEdit =
                                    canEditRelationshipStatus &&
                                    !isViewingOtherUser;

                                return _RelationshipStatusPill(
                                  value: value,
                                  onTap:
                                      canEdit
                                          ? () async {
                                            final selected = await showModalBottomSheet<
                                              RelationshipStatusTag
                                            >(
                                              context: context,
                                              backgroundColor:
                                                  Colors.transparent,
                                              isScrollControlled: false,
                                              builder: (sheetContext) {
                                                RelationshipStatusTag temp =
                                                    value;

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
                                                        color:
                                                            AppColors.surface,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              18,
                                                            ),
                                                      ),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
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
                                                                            FontWeight.w900,
                                                                      ),
                                                                ),
                                                              ),
                                                              InkWell(
                                                                onTap:
                                                                    () => Navigator.pop(
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
                                                          const SizedBox(
                                                            height: 12,
                                                          ),
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
                                                          const SizedBox(
                                                            height: 14,
                                                          ),
                                                          _StatusOptionTile(
                                                            label: 'Available',
                                                            selected:
                                                                temp ==
                                                                RelationshipStatusTag
                                                                    .available,
                                                            onTap: () async {
                                                              setSheetState(() {
                                                                temp =
                                                                    RelationshipStatusTag
                                                                        .available;
                                                              });
                                                              Navigator.pop(
                                                                sheetContext,
                                                                RelationshipStatusTag
                                                                    .available,
                                                              );
                                                            },
                                                          ),
                                                          const SizedBox(
                                                            height: 10,
                                                          ),
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

                                            await _setRelationshipStatusTagFirestore(
                                              profile.id,
                                              selected,
                                            );
                                            ref.invalidate(
                                              _relationshipStatusTagProvider(
                                                profile.id,
                                              ),
                                            );
                                          }
                                          : null,
                                );
                              },
                            ),
                            if (isViewingOtherUser)
                              _OverflowMenu(targetUid: profile.id),
                          ],
                        ),
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
          Icon(icon, size: 14, color: Colors.white),
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
                  'They will be hidden from you && you won’t be able to start a chat with them.',
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
                borderRadius: BorderRadius.circular(14),
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
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
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
    final aboutRaw = profile.bestQualitiesOrTraits?.trim();
    final about =
        (aboutRaw == null || aboutRaw.isEmpty)
            ? null
            : (aboutRaw.startsWith('http') ||
                aboutRaw.contains('digitaloceanspaces.com'))
            ? null
            : aboutRaw;

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

class _SendMessageCta extends ConsumerWidget {
  final UserModel profile;
  final String viewerUid;

  const _SendMessageCta({required this.profile, required this.viewerUid});

  String _displayName() {
    final u = (profile.username ?? '').trim();
    if (u.isNotEmpty) return u;
    final n = (profile.name ?? '').trim();
    if (n.isNotEmpty) return n;
    return 'User';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUid = profile.id.trim();
    final meUid = viewerUid.trim();

    if (meUid.isEmpty) return const SizedBox.shrink();
    if (otherUid.isEmpty) return const SizedBox.shrink();
    if (meUid == otherUid) return const SizedBox.shrink();

    final name = _displayName();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: AppColors.primary.withOpacity(0.22),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () async {
            try {
              final id = await ref.read(
                getOrCreateChatProvider(otherUid).future,
              );
              Navigator.of(context).pushNamed(AppNavRoutes.chat(id));
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(e.toString())));
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                // LEFT: chat icon container (same as yours)
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.35)),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),

                // CENTER: take remaining space and center the text
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Chat with $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // RIGHT: arrow icon pinned to right
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.white.withOpacity(0.95),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ------------------------------
/// SECTIONS
/// ------------------------------
class _Section extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Section({required this.title, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 8),
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
// ignore: unused_element
final _profileAudioControllerProvider = Provider<_ProfileAudioController>((
  ref,
) {
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
  bool _hasSource = false;

  // Track cached durations for URLs to avoid reloading
  final Map<String, Duration> _durationCache = {};

  String? lastError;
  VoidCallback? _notify;

  Future<void> init(VoidCallback notify) async {
    _notify = notify;
    if (_initialized) return;
    _initialized = true;

    try {
      await _player.setReleaseMode(ReleaseMode.stop);
    } catch (_) {}

    _player.onDurationChanged.listen((d) {
      duration = d;
      // Cache the duration for this URL
      if (currentUrl != null) {
        _durationCache[currentUrl!] = d;
      }
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

  /// Get duration for a specific URL (returns cached or current duration)
  Duration getDurationForUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return Duration.zero;

    // If this is the current URL, return the live duration
    if (currentUrl == u && duration != Duration.zero) {
      return duration;
    }

    // Otherwise return cached duration
    return _durationCache[u] ?? Duration.zero;
  }

  /// Preload duration for a URL without playing it
  Future<void> preloadDuration(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;

    // Return cached duration if available
    if (_durationCache.containsKey(u)) {
      duration = _durationCache[u]!;
      _notify?.call();
      return;
    }

    try {
      // Create a temporary player just to load duration
      final tempPlayer = AudioPlayer();

      // Set up a one-time listener for duration
      bool durationLoaded = false;
      tempPlayer.onDurationChanged.listen((d) {
        if (!durationLoaded && d != Duration.zero) {
          durationLoaded = true;
          _durationCache[u] = d;
          duration = d;
          _notify?.call();
          tempPlayer.dispose();
        }
      });

      // Start playing to trigger duration detection
      await tempPlayer.play(UrlSource(u));

      // Dispose after a short delay if duration wasn't loaded
      Future.delayed(const Duration(seconds: 2), () {
        if (!durationLoaded) {
          try {
            tempPlayer.dispose();
          } catch (_) {}
        }
      });
    } catch (e) {
      debugPrint('Error preloading duration for $u: $e');
    }
  }

  Future<void> playOrPause(String url) async {
    lastError = null;
    _notify?.call();
    final u = url.trim();
    if (u.isEmpty) return;

    try {
      if (currentUrl != u) {
        currentUrl = u;
        position = Duration.zero;

        // Use cached duration if available
        if (_durationCache.containsKey(u)) {
          duration = _durationCache[u]!;
        } else {
          duration = Duration.zero;
        }

        // stop only if we previously had a source
        if (_hasSource) {
          try {
            await _player.stop();
          } catch (_) {}
        }

        await _player.play(UrlSource(u));
        _hasSource = true;
        return;
      }

      // Same URL: toggle pause/play (avoid resume() — it often fails on iOS if native player isn't ready)
      if (state == PlayerState.playing) {
        try {
          await _player.pause();
        } catch (_) {}
        return;
      }

      await _player.play(UrlSource(u));
      _hasSource = true;
    } catch (e) {
      lastError = e.toString();
      _notify?.call();
    }
    ;
  }

  Future<void> seek(Duration d) async {
    if (!_hasSource) return;
    try {
      await _player.seek(d);
    } catch (_) {}
    ;
  }

  Future<void> stop() async {
    currentUrl = null;
    position = Duration.zero;
    duration = Duration.zero;

    if (!_hasSource) return;

    try {
      await _player.stop();
    } catch (_) {}

    _hasSource = false;
  }

  void dispose() {
    currentUrl = null;
    _hasSource = false;

    try {
      _player.stop();
    } catch (_) {}

    try {
      _player.dispose();
    } catch (_) {}
    ;
  }
}

class _AudioPromptsSection extends ConsumerStatefulWidget {
  final List<String> audioUrls;
  final bool isLocked;
  final bool isViewingOtherUser;
  final String? username;
  final String? gender;

  const _AudioPromptsSection({
    required this.audioUrls,
    required this.isLocked,
    required this.isViewingOtherUser,
    this.username,
    this.gender,
  });

  @override
  ConsumerState<_AudioPromptsSection> createState() =>
      _AudioPromptsSectionState();
}

class _AudioPromptsSectionState extends ConsumerState<_AudioPromptsSection> {
  late final _ProfileAudioController _controller = _ProfileAudioController();

  @override
  void initState() {
    super.initState();
    _controller.init(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _AudioPromptsSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldUrls =
        oldWidget.audioUrls
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    final newUrls =
        widget.audioUrls
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    final urlChanged = oldUrls.join('|') != newUrls.join('|');
    if (!urlChanged) return;

    final current = (_controller.currentUrl ?? '').trim();
    if (current.isEmpty) return;

    // If the currently-playing URL isn't in the new profile's list, stop.
    if (!newUrls.contains(current)) {
      _controller.stop();
    }
    ;
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.username ?? 'them';
    // Normalize gender: handles variations like "Male", "male", "man", "Female", "female", "woman", etc.
    final genderNormalized =
        (widget.gender ?? '').toString().trim().toLowerCase();
    final isFemale = genderNormalized.startsWith('f');
    final pronoun = isFemale ? 'herself' : 'himself';

    final prompts =
        widget.isViewingOtherUser
            ? [
              "$username's relationship with God",
              "$username's view on gender roles in marriage",
              "$username's favourite qualities about $pronoun",
            ]
            : const [
              'My relationship with God',
              'My view on gender roles in marriage',
              'Favourite qualities or traits about myself',
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

class _AudioPromptTile extends StatefulWidget {
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
  State<_AudioPromptTile> createState() => _AudioPromptTileState();
}

class _AudioPromptTileState extends State<_AudioPromptTile> {
  @override
  void initState() {
    super.initState();
    // Preload the duration when the tile is created
    if ((widget.url ?? '').trim().isNotEmpty) {
      widget.controller.preloadDuration(widget.url!);
    }
  }

  @override
  void didUpdateWidget(covariant _AudioPromptTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the URL changed, preload the new duration
    if (oldWidget.url != widget.url && (widget.url ?? '').trim().isNotEmpty) {
      widget.controller.preloadDuration(widget.url!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = (widget.url ?? '').trim().isNotEmpty;
    final isCurrent =
        hasUrl && (widget.controller.currentUrl == (widget.url ?? '').trim());
    final isPlaying =
        isCurrent && widget.controller.state == PlayerState.playing;

    // Get duration specific to this audio URL (not the shared controller duration)
    final audioDuration =
        hasUrl
            ? widget.controller.getDurationForUrl(widget.url!)
            : Duration.zero;
    final duration =
        audioDuration.inMilliseconds == 0
            ? const Duration(seconds: 1)
            : audioDuration;

    // Position is only relevant for the currently playing audio
    final position = isCurrent ? widget.controller.position : Duration.zero;

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
                    (!widget.isLocked && hasUrl)
                        ? () async {
                          await widget.controller.playOrPause(widget.url!);
                        }
                        : null,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 34,
                  width: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    widget.isLocked
                        ? Icons.lock_rounded
                        : hasUrl
                        ? (isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded)
                        : Icons.mic_off_rounded,
                    color:
                        widget.isLocked
                            ? AppColors.textSecondary
                            : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.prompt, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      widget.isLocked
                          ? 'Audio recordings cannot be changed after profile creation'
                          : hasUrl
                          ? ((isCurrent &&
                                  (widget.controller.lastError ?? '')
                                      .trim()
                                      .isNotEmpty)
                              ? 'Unable to play audio'
                              : (isPlaying ? 'Playing…' : 'Tap to play'))
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
          if (!widget.isLocked && hasUrl) ...[
            const SizedBox(height: 8),
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
                await widget.controller.seek(Duration(milliseconds: v.toInt()));
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
class _PremiumActionsRow extends ConsumerWidget {
  final bool isViewingOtherUser;
  final UserModel profile;

  const _PremiumActionsRow({
    required this.isViewingOtherUser,
    required this.profile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isViewingOtherUser) return const SizedBox.shrink();

    final isPremium = ref
        .watch(currentUserIsPremiumProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);

    // DEV ONLY: bypass premium gating for UI testing.
    // Run with: flutter run --dart-define=NEXUS_DEBUG_UNLOCK_PREMIUM=true
    const debugUnlockPremium = bool.fromEnvironment(
      'NEXUS_DEBUG_UNLOCK_PREMIUM',
      defaultValue: false,
    );

    final canViewPremiumGates = isPremium || (kDebugMode && debugUnlockPremium);

    return Row(
      children: [
        Expanded(
          child: _PremiumButton(
            icon: Icons.favorite_rounded,
            title: 'Compatibility Data',
            onTap: () {
              if (!canViewPremiumGates) {
                _toast(context, 'Upgrade to Premium to view compatibility.');
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) =>
                          _PremiumCompatibilityViewerScreen(profile: profile),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PremiumButton(
            icon: Icons.chat_bubble_rounded,
            title: 'Contact Info',
            onTap: () {
              if (!canViewPremiumGates) {
                _toast(context, 'Upgrade to Premium to view contact info.');
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _PremiumContactViewerScreen(profile: profile),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PremiumButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _PremiumButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
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
  final bool showEditProfile;
  const _AccountTiles(
    this.context,
    this.ref,
    this.profile, {
    this.showEditProfile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showEditProfile) ...[
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
        ],
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
          icon: Icons.workspace_premium_outlined,
          title: 'Subscriptions',
          subtitle: 'Upgrade for more features',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        _ProfileTile(
          icon: Icons.logout_rounded,
          title: 'Log out',
          subtitle: 'Sign out of your account',
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: const Text('Log out?'),
                    content: const Text(
                      'You will be signed out of your account.',
                    ),
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

            if (confirm != true) return;

            final prefs = await SharedPreferences.getInstance();
            // If you previously forced guest mode, clear it so bootstrap can show login.
            await prefs.remove('force_guest');

            await FirebaseAuth.instance.signOut();

            if (!context.mounted) return;

            // Route to welcome screen (with background image)
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const AppLaunchGate()),
              (_) => false,
            );
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
            Text('Dating Profile', style: AppTextStyles.headlineLarge),
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
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AppLaunchGate()),
                  ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(color: AppColors.border),
              ),
              child: Text('Log In', style: AppTextStyles.titleMedium),
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
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
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
                width: 34,
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

  if (c.isNotEmpty && k.isNotEmpty) {
    final lc = c.toLowerCase();
    final lk = k.toLowerCase();
    // Avoid duplicating city if residence string already includes it.
    if (lk.contains(lc)) return k;
    return '$c, $k';
  }

  if (c.isNotEmpty) return c;
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
  var s = value.toString().trim();
  if (s.startsWith('[') && s.endsWith(']') && s.length >= 2) {
    s = s.substring(1, s.length - 1).trim();
  }
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
    if (!_dirty || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final firebaseReady = ref.read(firebaseReadyProvider);
      final fs = ref.read(firestoreInstanceProvider);
      final user = FirebaseAuth.instance.currentUser;

      if (!firebaseReady || fs == null || user == null) {
        throw StateError('Firebase not ready. Please try again.');
      }

      // Normalize photos: remove duplicates, remove empty, enforce max 4
      final seen = <String>{};
      final cleanPhotos = <String>[];
      for (final p in _photos) {
        final v = p.trim();
        if (v.isEmpty) continue;
        if (seen.add(v)) cleanPhotos.add(v);
        if (cleanPhotos.length == 4) break;
      }

      // Upload any new local photos to Spaces; keep existing remote URLs intact
      final media = MediaService();
      final uploadedPhotos = <String>[];
      for (var i = 0; i < cleanPhotos.length; i++) {
        final path = cleanPhotos[i];
        if (path.startsWith('http')) {
          uploadedPhotos.add(path);
          continue;
        }

        final file = File(path);
        if (!await file.exists()) {
          throw StateError('Photo not found: $path');
        }

        final url = await media.uploadProfilePhoto(
          widget.profile.id,
          file,
          photoIndex: i,
        );
        uploadedPhotos.add(url);
      }

      final profileUrl =
          uploadedPhotos.isNotEmpty
              ? uploadedPhotos.first
              : widget.profile.profileUrl;

      final updates = <String, dynamic>{
        'name':
            _name.trim().isEmpty ? widget.profile.name ?? '' : _name.trim(),
        'age': _age,
        'city': _city.trim(),
        'country': _country.trim(),
        'nationality': _nationality.trim(),
        'educationLevel': _educationLevel.trim(),
        'profession': _profession.trim(),
        'churchName': _churchName.trim(),
        'desiredQualities': _qualities.join(', '),
        'hobbies': _hobbies,
        'photos': uploadedPhotos,
        'profileUrl': profileUrl,
        'instagramUsername': _instagram.trim(),
        'twitterUsername': _twitter.trim(),
        // WhatsApp stored as phoneNumber on UserModel
        'phoneNumber': _whatsapp.trim(),
        'facebookUsername': _facebook.trim(),
        'telegramUsername': _telegram.trim(),
        'snapchatUsername': _snapchat.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await fs
          .collection('users')
          .doc(widget.profile.id)
          .set(updates, SetOptions(merge: true));

      // Persist locally as a best-effort cache for offline reloads
      final updatedProfile = widget.profile.copyWith(
        name: updates['name'] as String?,
        age: _age,
        city: _city.trim(),
        country: _country.trim(),
        nationality: _nationality.trim(),
        educationLevel: _educationLevel.trim(),
        profession: _profession.trim(),
        churchName: _churchName.trim(),
        desiredQualities: _qualities.join(', '),
        hobbies: _hobbies,
        photos: uploadedPhotos,
        profileUrl: profileUrl,
        instagramUsername: _instagram.trim(),
        twitterUsername: _twitter.trim(),
        phoneNumber: _whatsapp.trim(),
        facebookUsername: _facebook.trim(),
        telegramUsername: _telegram.trim(),
        snapchatUsername: _snapchat.trim(),
      );

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

      if (!mounted) return;
      setState(() {
        _photos
          ..clear()
          ..addAll(uploadedPhotos);
        _isSaving = false;
        _dirty = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
                        borderRadius: BorderRadius.circular(16),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              _SearchField(
                controller: _hobbySearch,
                hint: 'Search hobbies',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              _SearchField(
                controller: _qualitySearch,
                hint: 'Search qualities',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
        Text(label, style: AppTextStyles.labelMedium.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initialValue,
          keyboardType: keyboardType,
          style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ignore: unused_element
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
        Text(label, style: AppTextStyles.labelMedium.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue.isEmpty ? null : safeValue,
              hint: Text(
                'Select $label',
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              items:
                  normalizedItems
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e,
                          child: Text(e, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall.copyWith(fontSize: 13)),
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

final _compatibilityMapProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, uid) {
      final firebaseReady = ref.watch(firebaseReadyProvider);
      if (!firebaseReady) return Stream.value(const <String, dynamic>{});

      final fs = ref.watch(firestoreInstanceProvider);
      if (fs == null) return Stream.value(const <String, dynamic>{});

      final trimmed = uid.trim();
      if (trimmed.isEmpty) return Stream.value(const <String, dynamic>{});

      return fs.collection('users').doc(trimmed).snapshots().map((doc) {
        if (!doc.exists) return const <String, dynamic>{};
        final data = doc.data();
        if (data == null) return const <String, dynamic>{};

        // v1 commonly had: compatibility: {...}
        dynamic compat = data['compatibility'];

        // v2 || alternate shapes may store under dating.*
        final dating = (data['dating'] is Map) ? data['dating'] as Map : null;
        compat =
            compat ??
            (dating != null ? dating['compatibility'] : null) ??
            (dating != null ? dating['compatibilityData'] : null) ??
            data['compatibility_data'];

        if (compat is Map) {
          return Map<String, dynamic>.from(compat);
        }
        return const <String, dynamic>{};
      });
    });

class _PremiumContactViewerScreen extends StatelessWidget {
  final UserModel profile;
  const _PremiumContactViewerScreen({required this.profile});

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _copy(context, label, value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Copy',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name =
        (profile.name ?? '').trim().isEmpty
            ? (profile.username ?? '').trim()
            : (profile.name ?? '').trim();

    final ig = (profile.instagramUsername ?? '').trim();
    final wa = (profile.phoneNumber ?? '').trim();
    final email = (profile.email ?? '').trim();

    final tiles = <Widget>[];
    if (email.isNotEmpty) {
      tiles.add(
        _infoTile(
          context,
          icon: Icons.mail_rounded,
          label: 'Email',
          value: email,
        ),
      );
    }
    if (ig.isNotEmpty) {
      tiles.add(
        _infoTile(
          context,
          icon: Icons.alternate_email_rounded,
          label: 'Instagram',
          value: '@$ig',
        ),
      );
    }
    if (wa.isNotEmpty) {
      tiles.add(
        _infoTile(
          context,
          icon: Icons.chat_bubble_rounded,
          label: 'WhatsApp',
          value: wa,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        title: Text('Contact info', style: AppTextStyles.headlineLarge),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Contact info' : name,
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Use these details to connect respectfully.\nTap Copy to save a detail.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (tiles.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No contact info available yet.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: tiles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => tiles[i],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumCompatibilityViewerScreen extends ConsumerWidget {
  final UserModel profile;
  const _PremiumCompatibilityViewerScreen({required this.profile});

  String _profileUid() {
    try {
      final dynamic p = profile;
      final dynamic id = p.id ?? p.uid;
      return (id ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  String _normGender(String? g) {
    final v = (g ?? '').trim().toLowerCase();
    if (v.isEmpty) return '';
    if (v.startsWith('m')) return 'male';
    if (v.startsWith('f')) return 'female';
    return v;
  }

  Map<String, String> _pronouns() {
    final g1 = _normGender(profile.gender);
    final g2 = _normGender(profile.nexus2?.gender);
    final g = g1.isNotEmpty ? g1 : g2;

    if (g == 'female') {
      return const <String, String>{
        'subj': 'she',
        'obj': 'her',
        'possAdj': 'her',
        'poss': 'hers',
      };
    }

    // default male (safe fallback)
    return const <String, String>{
      'subj': 'he',
      'obj': 'him',
      'possAdj': 'his',
      'poss': 'his',
    };
  }

  String _cap(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  String _normKey(String k) {
    return k.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  bool? _yesNo(String v) {
    final t = v.trim().toLowerCase();
    if (t.isEmpty) return null;

    // handle leading "yes, ..." / "no, ..."
    if (t.startsWith('yes')) return true;
    if (t.startsWith('no')) return false;

    if (t == 'true' || t == '1') return true;
    if (t == 'false' || t == '0') return false;

    return null;
  }

  // v1-like ordering:
  // marital_status, have_kids, genotype, personality_type, regular_source_of_income,
  // marry_someone_fs, long_distance, believe_cohabiting,
  // should_christian_speak_in_tongue, believe_in_tithing
  List<MapEntry<String, dynamic>> _sortedEntries(Map<String, dynamic> m) {
    final entries = m.entries.toList();

    int rank(MapEntry<String, dynamic> e) {
      final k = _normKey(e.key.toString());

      bool hasAny(List<String> needles) => needles.any((n) => k.contains(n));

      if (hasAny(['maritalstatus', 'marital_status', 'marital'])) return 0;
      if (hasAny(['havekids', 'have_kids', 'kids'])) return 1;
      if (hasAny(['genotype'])) return 2;
      if (hasAny(['personalitytype', 'personality_type', 'personality']))
        return 3;
      if (hasAny([
        'regularsourceofincome',
        'regular_source_of_income',
        'sourceofincome',
        'income',
      ]))
        return 4;
      if (hasAny([
        'marrysomeonefs',
        'marry_someone_fs',
        'financialstability',
        'financial',
      ]))
        return 5;
      if (hasAny(['longdistance', 'long_distance', 'distance'])) return 6;
      if (hasAny([
        'believecohabiting',
        'believe_cohabiting',
        'cohabit',
        'cohabiting',
      ]))
        return 7;
      if (hasAny([
        'shouldchristianspeakintongue',
        'should_christian_speak_in_tongue',
        'tongue',
        'tongues',
      ]))
        return 8;
      if (hasAny(['believeintithing', 'believe_in_tithing', 'tith'])) return 9;

      return 100; // unknown -> bottom
    }

    entries.sort((a, b) {
      final ra = rank(a);
      final rb = rank(b);
      if (ra != rb) return ra.compareTo(rb);
      return a.key.toString().compareTo(b.key.toString());
    });

    return entries;
  }

  String _labelFor(String rawKey) {
    final k = _normKey(rawKey);

    if (k.contains('marital')) return 'Marital Status';
    if (k.contains('havekids') ||
        k.contains('have_kids') ||
        k == 'kids' ||
        k.contains('kids'))
      return 'Kids';
    if (k.contains('genotype')) return 'Genotype';
    if (k.contains('personality')) return 'Personality Type';
    if (k.contains('regularsourceofincome') ||
        k.contains('sourceofincome') ||
        k == 'income' ||
        k.contains('income')) {
      return 'Source of Income';
    }
    if (k.contains('marrysomeonefs') ||
        k.contains('marry_someone_fs') ||
        k.contains('financial')) {
      return 'Financial Stability';
    }
    if (k.contains('longdistance') ||
        k.contains('long_distance') ||
        (k.contains('distance') && !k.contains('country'))) {
      return 'Long Distance';
    }
    if (k.contains('cohabit')) return 'Cohabiting';
    if (k.contains('tongue')) return 'Speaking in Tongues';
    if (k.contains('tith')) return 'Tithing';

    // fallback: prettify key
    final spaced = rawKey.replaceAll('_', ' ').trim();
    return spaced.isEmpty ? 'Compatibility' : _cap(spaced);
  }

  String _sentenceFor({
    required String rawKey,
    required String rawValue,
    required Map<String, String> p,
  }) {
    final subj = _cap(p['subj'] ?? 'they');
    final k = _normKey(rawKey);
    final v = rawValue.trim();
    final yn = _yesNo(v);

    // Marital status
    if (k.contains('marital')) {
      if (v.isEmpty) return '$subj has not shared marital status.';
      return '$subj is ${v.toLowerCase()}.';
    }

    // Kids
    if (k.contains('havekids') ||
        k.contains('have_kids') ||
        k == 'kids' ||
        k.contains('kids')) {
      if (yn == true) return '$subj has kids.';
      if (yn == false) return '$subj does not have kids.';
      if (v.isEmpty) return '$subj has not shared whether they have kids.';
      return '$subj believes $v.';
    }

    // Genotype
    if (k.contains('genotype')) {
      if (v.isEmpty) return '$subj has not shared genotype.';
      final possAdj = _cap(p['possAdj'] ?? 'their');
      return '$possAdj genotype is $v.';
    }

    // Personality type
    if (k.contains('personality')) {
      if (v.isEmpty) return '$subj has not shared personality type.';
      final vv = v.toLowerCase();
      if (vv == 'introvert' || vv == 'extrovert' || vv == 'ambivert') {
        return '$subj is an $vv.';
      }
      final possAdj = _cap(p['possAdj'] ?? 'their');
      return '$possAdj personality type is $v.';
    }

    // Source of income
    if (k.contains('regularsourceofincome') ||
        k.contains('regular_source_of_income') ||
        k.contains('sourceofincome') ||
        k == 'income' ||
        k.contains('income')) {
      if (yn == true) return '$subj has a regular source of income.';
      if (yn == false) return '$subj does not have a regular source of income.';
      if (v.isEmpty)
        return '$subj has not shared whether they have a regular source of income.';
      return '$subj believes $v.';
    }

    // Financial stability (your requested grammar)
    // meaning: can/cannot marry someone who is NOT financially stable yet
    if (k.contains('marrysomeonefs') ||
        k.contains('marry_someone_fs') ||
        k.contains('financial')) {
      if (yn == true)
        return '$subj can marry someone who is not yet financially stable.';
      if (yn == false)
        return '$subj cannot marry someone who is not yet financially stable.';
      if (v.isEmpty)
        return '$subj has not shared their view on marrying someone who is not yet financially stable.';
      return '$subj believes $v.';
    }

    // Long distance
    if (k.contains('longdistance') ||
        k.contains('long_distance') ||
        k == 'distance' ||
        k.contains('distance')) {
      if (yn == true) return '$subj is open to a long-distance relationship.';
      if (yn == false)
        return '$subj is not open to a long-distance relationship.';
      if (v.isEmpty)
        return '$subj has not shared their view on long-distance relationships.';
      return '$subj believes $v.';
    }

    // Cohabiting
    if (k.contains('cohabit') || k.contains('cohabiting')) {
      if (yn == true) return '$subj believes in cohabiting before marriage.';
      if (yn == false)
        return '$subj does not believe in cohabiting before marriage.';
      if (v.isEmpty)
        return '$subj has not shared their view on cohabiting before marriage.';
      return '$subj believes $v.';
    }

    // Speaking in tongues
    if (k.contains('tongue') || k.contains('tongues')) {
      if (yn == true)
        return '$subj believes every Christian should desire to speak in tongues.';
      if (yn == false)
        return '$subj does not believe every Christian should desire to speak in tongues.';
      if (v.isEmpty)
        return '$subj has not shared their view on speaking in tongues.';
      return '$subj believes $v.';
    }

    // Tithing (your requested grammar)
    if (k.contains('tith')) {
      if (yn == true) return '$subj believes in tithing.';
      if (yn == false) return '$subj does not believe in tithing.';
      if (v.isEmpty) return '$subj has not shared their view on tithing.';
      return '$subj believes $v.';
    }

    // fallback
    if (v.isEmpty) return '$subj has not provided an answer.';
    return '$subj believes $v.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name =
        (profile.name ?? '').trim().isEmpty
            ? (profile.username ?? '').trim()
            : (profile.name ?? '').trim();

    final uid = _profileUid();
    if (uid.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          elevation: 0,
          title: Text('Compatibility', style: AppTextStyles.headlineLarge),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Unable to load compatibility right now (missing profile id).',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final compatAsync = ref.watch(_compatibilityMapProvider(uid));
    final p = _pronouns();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        title: Text('Compatibility', style: AppTextStyles.headlineLarge),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: compatAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (e, _) => Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'Unable to load compatibility right now. Please try again.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                data: (compat) {
                  final entries = _sortedEntries(compat);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty
                            ? 'Compatibility'
                            : 'Compatibility with $name',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'These insights are based on questionnaire data stored on the profile.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textMuted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (entries.isEmpty)
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No compatibility data available yet for this profile.\n\nIf this is unexpected, the profile may not have completed the compatibility questionnaire.',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: entries.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final e = entries[i];
                              final label = _labelFor(e.key.toString());
                              final value = (e.value ?? '').toString().trim();
                              final sentence = _sentenceFor(
                                rawKey: e.key.toString(),
                                rawValue: value,
                                p: p,
                              );

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 38,
                                      width: 38,
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.insights_rounded,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            label,
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                  height: 1.1,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            sentence,
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(height: 1.25),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
