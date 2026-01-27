import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/providers/auth_provider.dart';
import 'package:nexus_app_min_test/core/providers/service_providers.dart';
import 'package:nexus_app_min_test/core/user/dating_profile_completed_provider.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/core/user/dating_opt_in_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexus_app_min_test/core/models/user_model.dart';
import 'package:nexus_app_min_test/features/launch/presentation/app_launch_gate.dart';

final _userDocByIdProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((doc) => doc.exists ? doc.data() : null);
    });

String _formatChatTime(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inMinutes < 1) return 'Now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d';
  // Keep it simple (avoid intl dependency here)
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

String _displayNameFromOtherId(String otherUserId) {
  final id = otherUserId.trim();
  if (id.isEmpty) return 'Unknown';
  // Temporary: show a short id until we wire "other user's name" lookup.
  return 'User ${id.substring(0, 6)}';
}

String? _bestAvatarUrl(Map<String, dynamic>? u) {
  if (u == null) return null;

  // Common locations:
  // - profileUrl
  // - photos[0]
  // - nexus2.photos[0]
  final direct = (u['profileUrl'] ?? '').toString().trim();
  if (direct.isNotEmpty) return direct;

  final photos = u['photos'];
  if (photos is List && photos.isNotEmpty) {
    final v = (photos.first ?? '').toString().trim();
    if (v.isNotEmpty) return v;
  }

  final nexus2 = u['nexus2'];
  if (nexus2 is Map) {
    final n2photos = nexus2['photos'];
    if (n2photos is List && n2photos.isNotEmpty) {
      final v = (n2photos.first ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    final n2url = (nexus2['profileUrl'] ?? '').toString().trim();
    if (n2url.isNotEmpty) return n2url;
  }

  return null;
}

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final user = authAsync.maybeWhen(data: (u) => u, orElse: () => null);
    final isSignedIn = user != null && !user.isAnonymous;
    final uid = user?.uid;
    // Signed-in gating for Chats:
    // - Guests must not see chat UI.
    // - If dating is turned off, chats are unavailable.
    // - If dating profile is incomplete, chats are unavailable.
    final optedInAsync = ref.watch(datingOptInProvider);
    final optedIn = optedInAsync.maybeWhen(data: (v) => v, orElse: () => true);

    final completedAsync = ref.watch(datingProfileCompletedProvider);
    final isProfileComplete = completedAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

    if (!isSignedIn) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          surfaceTintColor: AppColors.getBackground(context),
          elevation: 0,
          titleSpacing: 20,
          title: Text(
            'Chats',
            style: AppTextStyles.headlineLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.getBorder(context).withOpacity(0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Create an account to chat',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Create an account to send and receive messages.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.getTextSecondary(context),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            () => Navigator.of(context).pushNamed('/signup'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Create an account',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed:
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AppLaunchGate(),
                              ),
                            ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.getBorder(context)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Log in',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
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

    // Dating opt-in gate
    if (isSignedIn && !optedIn) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          title: Text('Chats', style: AppTextStyles.headlineLarge),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.getBorder(context)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Turn on dating to use chats',
                    style: AppTextStyles.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chats are part of the dating experience. Enable dating in your profile to continue.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed:
                          () => Navigator.of(context).pushNamed('/profile'),
                      child: const Text('Go to Profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Dating profile completion gate
    if (isSignedIn && !isProfileComplete) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          title: Text('Chats', style: AppTextStyles.headlineLarge),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.getBorder(context)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Complete your dating profile',
                    style: AppTextStyles.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You need a completed dating profile to use chats.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed:
                          () => Navigator.of(
                            context,
                          ).pushNamed('/dating/setup/age'),
                      child: const Text('Complete profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ✅ Real conversations list (Firestore-backed)
    final conversationsAsync = ref.watch(userConversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        titleSpacing: 20,
        title: Text(
          'Chats',
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent conversations',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: conversationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, __) {
                  // Permission-denied errors for v1 users are expected
                  // (they have no v2 chats). Treat as empty state.
                  final errStr = err.toString().toLowerCase();
                  if (errStr.contains('permission-denied') ||
                      errStr.contains('permission denied')) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 56,
                            color: AppColors.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'You don\'t have any conversations yet',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start connecting with other members.\nNew conversations will appear here.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed:
                                  () => Navigator.of(
                                    context,
                                  ).pushNamed('/search'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Start Connecting'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  // For other errors, show error message
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Could not load chats.\n${err.toString()}',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ),
                  );
                },
                data: (conversations) {
                  final me = uid;
                  if (me == null) {
                    return Center(
                      child: Text(
                        'Please sign in to view your chats.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    );
                  }

                  // Only show chats where someone has actually messaged
                  // (lastMessage exists) OR there are unread messages.
                  final visible =
                      conversations.where((c) {
                        final last = (c.lastMessage ?? '').trim();
                        final unreadCount = c.getUnreadCount(me);
                        return last.isNotEmpty || unreadCount > 0;
                      }).toList();

                  if (visible.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 56,
                            color: AppColors.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'You don\'t have any conversations yet',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start connecting with other members.\nNew conversations will appear here.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed:
                                  () => Navigator.of(
                                    context,
                                  ).pushNamed('/search'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Start Connecting'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final c = visible[index];
                      final otherId = c.participantIds.firstWhere(
                        (id) => id != me,
                        orElse: () => '',
                      );

                      final subtitle =
                          (c.lastMessage ?? '').trim().isEmpty
                              ? 'Say hi 👋'
                              : (c.lastMessage ?? '');
                      final time = _formatChatTime(c.lastMessageAt);
                      final unread = c.getUnreadCount(me) > 0;

                      final otherAsync = ref.watch(
                        _userDocByIdProvider(otherId),
                      );
                      return otherAsync.when(
                        loading: () {
                          return _ChatRow(
                            name: _displayNameFromOtherId(otherId),
                            message: subtitle,
                            time: time,
                            unread: unread,
                            avatarUrl: null,
                            onTap: () {
                              Navigator.of(context).pushNamed('/chats/${c.id}');
                            },
                          );
                        },
                        error: (_, __) {
                          return _ChatRow(
                            name: _displayNameFromOtherId(otherId),
                            message: subtitle,
                            time: time,
                            unread: unread,
                            avatarUrl: null,
                            onTap: () {
                              Navigator.of(context).pushNamed('/chats/${c.id}');
                            },
                          );
                        },
                        data: (data) {
                          final model =
                              data == null
                                  ? null
                                  : UserModel.fromMap(otherId, data);

                          final username = (model?.username ?? '').trim();
                          final nameFromDoc = (model?.name ?? '').trim();

                          final displayName =
                              username.isNotEmpty
                                  ? username
                                  : (nameFromDoc.isNotEmpty
                                      ? nameFromDoc
                                      : _displayNameFromOtherId(otherId));

                          final avatarUrl = _bestAvatarUrl(data);

                          return _ChatRow(
                            name: displayName,
                            message: subtitle,
                            time: time,
                            unread: unread,
                            avatarUrl: avatarUrl,
                            onTap: () {
                              Navigator.of(context).pushNamed('/chats/${c.id}');
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatRow extends StatefulWidget {
  final String name;
  final String message;
  final String time;
  final bool unread;
  final VoidCallback onTap;
  final String? avatarUrl;

  const _ChatRow({
    required this.name,
    required this.message,
    required this.time,
    required this.unread,
    required this.onTap,
    this.avatarUrl,
  });

  @override
  State<_ChatRow> createState() => _ChatRowState();
}

class _ChatRowState extends State<_ChatRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverScale;
  late Animation<double> _shadowElev;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _hoverScale = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));
    _shadowElev = Tween<double>(
      begin: 0,
      end: 8,
    ).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = (widget.avatarUrl ?? '').trim();
    final initials = _getInitials(widget.name);

    final Widget avatar = Stack(
      children: [
        // Avatar background
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _getAvatarColors(initials),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child:
                url.isNotEmpty
                    ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: 56,
                      height: 56,
                      errorBuilder:
                          (_, __, ___) => _buildInitialAvatar(initials),
                    )
                    : _buildInitialAvatar(initials),
          ),
        ),
        // Online indicator
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.getSurface(context),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return AnimatedBuilder(
      animation: _hoverController,
      builder: (context, child) {
        return Transform.scale(
          scale: _hoverScale.value,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onHover: (isHover) {
                if (isHover) {
                  _hoverController.forward();
                } else {
                  _hoverController.reverse();
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color:
                      widget.unread
                          ? AppColors.primary.withOpacity(0.06)
                          : AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        widget.unread
                            ? AppColors.primary.withOpacity(0.15)
                            : AppColors.getBorder(context).withOpacity(0.4),
                    width: widget.unread ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        0.03 * _shadowElev.value / 8,
                      ),
                      blurRadius: 8 * (_shadowElev.value / 8),
                      offset: Offset(0, 2 * (_shadowElev.value / 8)),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    avatar,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name and time row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.name,
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight:
                                        widget.unread
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                    fontSize: 16,
                                    letterSpacing: 0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.time,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                  fontSize: 12,
                                  fontWeight:
                                      widget.unread
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          // Message preview
                          Container(
                            constraints: const BoxConstraints(maxHeight: 40),
                            child: Text(
                              widget.message,
                              style: AppTextStyles.bodySmall.copyWith(
                                color:
                                    widget.unread
                                        ? AppColors.getTextPrimary(context)
                                        : AppColors.getTextSecondary(context),
                                fontWeight:
                                    widget.unread
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.unread) ...[
                      const SizedBox(width: 12),
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _hoverController,
                            curve: Curves.elasticOut,
                          ),
                        ),
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  List<Color> _getAvatarColors(String initials) {
    final colors = [
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFFF093FB), const Color(0xFFF5576C)],
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
      [const Color(0xFFFA709A), const Color(0xFFFECE34)],
      [const Color(0xFF30cfd0), const Color(0xFF330867)],
      [const Color(0xFFa8edea), const Color(0xFFFED6E3)],
      [const Color(0xFFFF9A56), const Color(0xFFFF6A88)],
      [const Color(0xFF5ef8d9), const Color(0xFF3d84e7)],
    ];
    final hash = initials.codeUnitAt(0) % colors.length;
    return colors[hash];
  }

  Widget _buildInitialAvatar(String initials) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getAvatarColors(initials),
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
