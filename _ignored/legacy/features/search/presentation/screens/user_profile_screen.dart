import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/search_provider.dart';
import '../../../../core/widgets/app_loading_states.dart';

/// Premium User Profile View Screen
/// Shows another user's profile with:
/// - Full photo gallery
/// - Bio and details
/// - Message button (prominent)
/// - Save/Bookmark button
/// - Report/Block options
class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  int _currentPhotoIndex = 0;
  final PageController _photoController = PageController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userByIdProvider(widget.userId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const AppErrorState(
              title: 'Profile Not Found',
              message: 'This profile may no longer be available.',
            );
          }
          return FadeTransition(
            opacity: _fadeIn,
            child: _buildContent(context, user, currentUser),
          );
        },
        loading: () => const AppLoadingScreen(),
        error: (e, _) => AppErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(userByIdProvider(widget.userId)),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, UserModel user, UserModel? currentUser) {
    final photos = user.photos ?? [];
    final isSaved = ref.watch(isProfileSavedProvider(user.id));

    return Stack(
      children: [
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Photo Gallery Header
            SliverAppBar(
              expandedHeight: MediaQuery.of(context).size.height * 0.55,
              pinned: true,
              backgroundColor: AppColors.primary,
              leading: _buildBackButton(context),
              actions: [
                _buildMoreButton(context, user),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildPhotoGallery(photos, user),
              ),
            ),

            // Profile Content
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Name and Age
                  _buildNameSection(user),
                  const SizedBox(height: 20),

                  // Quick Info Cards
                  _buildQuickInfoCards(user),
                  const SizedBox(height: 24),

                  // About Section
                  if (user.bestQualitiesOrTraits?.isNotEmpty == true) ...[
                    _buildSectionTitle('About Me'),
                    const SizedBox(height: 12),
                    _buildAboutCard(user),
                    const SizedBox(height: 24),
                  ],

                  // Hobbies
                  if (user.hobbies?.isNotEmpty == true) ...[
                    _buildSectionTitle('Interests'),
                    const SizedBox(height: 12),
                    _buildHobbiesChips(user.hobbies!),
                    const SizedBox(height: 24),
                  ],

                  // Desired Qualities
                  if (user.desiredQualities?.isNotEmpty == true) ...[
                    _buildSectionTitle('Looking For'),
                    const SizedBox(height: 12),
                    _buildDesiredQualitiesCard(user),
                    const SizedBox(height: 24),
                  ],

                  // Faith Section
                  _buildSectionTitle('Faith & Values'),
                  const SizedBox(height: 12),
                  _buildFaithCard(user),
                ]),
              ),
            ),
          ],
        ),

        // Floating Action Buttons
        Positioned(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
          child: _buildActionButtons(context, user, currentUser, isSaved),
        ),
      ],
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildMoreButton(BuildContext context, UserModel user) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: () => _showOptionsSheet(context, user),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildPhotoGallery(List<String> photos, UserModel user) {
    if (photos.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Photo PageView
        PageView.builder(
          controller: _photoController,
          itemCount: photos.length,
          onPageChanged: (index) {
            setState(() => _currentPhotoIndex = index);
          },
          itemBuilder: (context, index) {
            return Image.network(
              photos[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surfaceLight,
                child: const Icon(Icons.person, size: 80, color: Colors.white54),
              ),
            );
          },
        ),

        // Gradient overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
                stops: const [0.0, 0.2, 0.6, 1.0],
              ),
            ),
          ),
        ),

        // Photo indicators
        if (photos.length > 1)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 20,
            right: 20,
            child: Row(
              children: List.generate(photos.length, (index) {
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(right: index < photos.length - 1 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: _currentPhotoIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),

        // Verified badge
        if (user.isVerified == true)
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Verified',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Online indicator
        if (user.isOnline == true)
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Online now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNameSection(UserModel user) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${user.displayName}, ${user.age ?? '?'}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _getLocation(user),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Premium badge
        if (user.isPremium)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQuickInfoCards(UserModel user) {
    return Row(
      children: [
        _QuickInfoCard(
          icon: Icons.school,
          label: 'Education',
          value: user.educationLevel ?? 'Not specified',
        ),
        const SizedBox(width: 12),
        _QuickInfoCard(
          icon: Icons.work,
          label: 'Profession',
          value: user.profession ?? 'Not specified',
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildAboutCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        user.bestQualitiesOrTraits ?? '',
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildHobbiesChips(List<String> hobbies) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: hobbies.map((hobby) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            hobby,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDesiredQualitiesCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.favorite_border, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.desiredQualities ?? '',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaithCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _FaithRow(
            icon: Icons.church,
            label: 'Church',
            value: user.churchName ?? 'Not specified',
          ),
          const SizedBox(height: 12),
          _FaithRow(
            icon: Icons.auto_awesome,
            label: 'Faith',
            value: user.relationshipWithGod ?? 'Not specified',
          ),
          if (user.roleOfHusband?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _FaithRow(
              icon: Icons.people,
              label: 'Views on Marriage',
              value: user.roleOfHusband!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, UserModel user, UserModel? currentUser, bool isSaved) {
    // Both the viewer AND the profile being viewed must be single to message
    final viewerIsSingle = currentUser?.isSingle ?? false;
    final profileIsSingle = user.isSingle;
    final canMessage = viewerIsSingle && profileIsSingle;

    return Row(
      children: [
        // Save/Bookmark button
        _ActionButton(
          icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
          color: isSaved ? Colors.white : AppColors.textSecondary,
          bgColor: isSaved ? AppColors.primary : AppColors.surface,
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(savedProfilesProvider.notifier).toggleSave(user.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isSaved ? 'Removed from saved' : 'Profile saved!'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: isSaved ? AppColors.textSecondary : AppColors.primary,
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
        const SizedBox(width: 12),

        // Message button - Only for singles
        if (canMessage)
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                context.push('/chat/${user.id}');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Send Message',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Spacer if no message button
        if (!canMessage)
          const Spacer(),
      ],
    );
  }

  void _showOptionsSheet(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _OptionItem(
              icon: Icons.share,
              title: 'Share Profile',
              onTap: () => Navigator.pop(context),
            ),
            _OptionItem(
              icon: Icons.block,
              title: 'Block User',
              color: AppColors.warning,
              onTap: () => Navigator.pop(context),
            ),
            _OptionItem(
              icon: Icons.flag,
              title: 'Report Profile',
              color: AppColors.error,
              onTap: () => Navigator.pop(context),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  String _getLocation(UserModel user) {
    final parts = <String>[];
    if (user.city?.isNotEmpty == true) parts.add(user.city!);
    if (user.stateOfOrigin?.isNotEmpty == true) parts.add(user.stateOfOrigin!);
    if (user.country?.isNotEmpty == true) parts.add(user.country!);
    return parts.isNotEmpty ? parts.join(', ') : 'Location not specified';
  }
}

// ============================================================================
// SUPPORTING WIDGETS
// ============================================================================

class _QuickInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _QuickInfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _FaithRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _FaithRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

class _OptionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback onTap;

  const _OptionItem({
    required this.icon,
    required this.title,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: itemColor, size: 22),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: itemColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
