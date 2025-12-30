import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/firestore_service.dart';

/// Provider to fetch a user by ID
final userByIdProvider = FutureProvider.family<UserModel?, String>((ref, userId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final doc = await firestoreService.getUser(userId);
  return doc;
});

/// Screen to view another user's profile (from search results)
class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingAudioIndex;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _playingAudioIndex = null;
        _currentPosition = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userByIdProvider(widget.userId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Colors.white,
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return _buildErrorState(context, 'User not found');
          }
          return _buildProfileContent(context, user, currentUser);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildErrorState(context, e.toString()),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(context, null),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text(message, style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, UserModel user, UserModel? currentUser) {
    return CustomScrollView(
      slivers: [
        // App Bar with profile photo
        SliverAppBar(
          expandedHeight: 400,
          pinned: true,
          backgroundColor: Colors.white,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => _showOptionsMenu(context, user),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.more_vert, color: Colors.white),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _buildProfileHeader(user),
          ),
        ),

        // Profile content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and age
                Row(
                  children: [
                    Text(
                      '${user.username ?? user.name ?? 'User'}, ${user.age ?? '?'}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (user.isVerified == true) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.verified, color: Colors.blue, size: 24),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      _getLocation(user),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // About section
                _buildSectionTitle('About'),
                const SizedBox(height: 12),
                _buildInfoRow('Nationality', user.nationality ?? 'Not specified'),
                _buildInfoRow('State of Origin', user.stateOfOrigin ?? 'Not specified'),
                _buildInfoRow('Education Level', user.educationLevel ?? 'Not specified'),
                _buildInfoRow('Profession', user.profession ?? 'Not specified'),
                _buildInfoRow('Church', user.churchName ?? 'Not specified'),
                const SizedBox(height: 24),

                // Hobbies
                if (user.hobbies != null && user.hobbies!.isNotEmpty) ...[
                  _buildSectionTitle('Hobbies / Interests'),
                  const SizedBox(height: 12),
                  _buildChips(user.hobbies!, AppColors.primary),
                  const SizedBox(height: 24),
                ],

                // Desired Qualities
                if (user.desiredQualities != null && user.desiredQualities!.isNotEmpty) ...[
                  _buildSectionTitle('Most Desired Qualities'),
                  const SizedBox(height: 12),
                  _buildChips(_parseQualities(user.desiredQualities!), AppColors.secondary),
                  const SizedBox(height: 24),
                ],

                // Audio Recordings
                _buildAudioSection(user),

                // Photo Gallery
                _buildPhotoGallery(user),

                const SizedBox(height: 100), // Space for bottom buttons
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context, UserModel? user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          const Spacer(),
          if (user != null)
            IconButton(
              onPressed: () => _showOptionsMenu(context, user),
              icon: const Icon(Icons.more_vert),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    final photoUrl = user.profileUrl ??
        (user.photos?.isNotEmpty == true ? user.photos!.first : null);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Profile photo
        if (photoUrl != null)
          Image.network(
            photoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(user),
          )
        else
          _buildPhotoPlaceholder(user),

        // Gradient overlay at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 150,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
        ),

        // Premium badge
        if (user.isPremium)
          Positioned(
            top: 100,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoPlaceholder(UserModel user) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.8),
            AppColors.secondary.withOpacity(0.8),
          ],
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(user),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 80,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChips(List<String> items, Color color) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            item,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAudioSection(UserModel user) {
    // Check for audio URLs in the user data
    final audioUrls = <String, String?>{};
    if (user.compatibility != null) {
      audioUrls['Relationship with God'] = user.compatibility!['audio1Url'] as String?;
      audioUrls['Gender roles in marriage'] = user.compatibility!['audio2Url'] as String?;
      audioUrls['Favorite qualities about myself'] = user.compatibility!['audio3Url'] as String?;
    }

    final validAudios = audioUrls.entries.where((e) => e.value != null && e.value!.isNotEmpty).toList();

    if (validAudios.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Audio Recordings'),
        const SizedBox(height: 12),
        ...validAudios.asMap().entries.map((entry) {
          final index = entry.key;
          final audio = entry.value;
          return _buildAudioPlayer(index, audio.key, audio.value!);
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAudioPlayer(int index, String title, String url) {
    final isCurrentPlaying = _playingAudioIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. $title',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: () => _toggleAudio(index, url),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCurrentPlaying && _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Waveform visualization (simplified)
              Expanded(
                child: Column(
                  children: [
                    // Progress indicator
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: isCurrentPlaying && _totalDuration.inMilliseconds > 0
                            ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
                            : 0,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Duration
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(isCurrentPlaying ? _currentPosition : Duration.zero),
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                        Text(
                          _formatDuration(isCurrentPlaying ? _totalDuration : const Duration(seconds: 60)),
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGallery(UserModel user) {
    final photos = user.photos ?? [];
    if (photos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Gallery'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _showPhotoViewer(context, photos, index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  photos[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.surfaceLight,
                    child: Icon(Icons.broken_image, color: AppColors.textMuted),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _showPhotoViewer(BuildContext context, List<String> photos, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => PhotoViewerDialog(
        photos: photos,
        initialIndex: initialIndex,
      ),
    );
  }

  void _showOptionsMenu(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Block User'),
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation(context, user);
              },
            ),
            ListTile(
              leading: Icon(Icons.flag, color: AppColors.error),
              title: Text('Report User', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(context, user);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmation(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block ${user.username ?? user.name}? They won\'t be able to message you or see your profile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _blockUser(user);
            },
            child: Text('Block', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, UserModel user) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Why are you reporting ${user.username ?? user.name}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Please describe the issue...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }
              Navigator.pop(context);
              await _reportUser(user, reasonController.text.trim());
            },
            child: Text('Report', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser(UserModel user) async {
    try {
      final currentUserId = ref.read(currentUserIdProvider);
      if (currentUserId == null) return;

      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.blockUser(currentUserId, user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.username ?? user.name} has been blocked'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to block user: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _reportUser(UserModel user, String reason) async {
    try {
      final currentUserId = ref.read(currentUserIdProvider);
      if (currentUserId == null) return;

      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.reportUser(
        reporterId: currentUserId,
        reportedUserId: user.id,
        reason: reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. Thank you for keeping our community safe.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleAudio(int index, String url) async {
    if (_playingAudioIndex == index && _isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_playingAudioIndex != index) {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(url));
      } else {
        await _audioPlayer.resume();
      }
      setState(() {
        _playingAudioIndex = index;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getLocation(UserModel user) {
    if (user.city != null && user.country != null) {
      return '${user.city}, ${user.country}';
    }
    return user.city ?? user.country ?? user.location?.toString() ?? 'Unknown';
  }

  String _getInitials(UserModel user) {
    final name = user.username ?? user.name ?? 'U';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  List<String> _parseQualities(String qualities) {
    // Qualities might be stored as comma-separated or newline-separated
    return qualities
        .split(RegExp(r'[,\n]'))
        .map((q) => q.trim())
        .where((q) => q.isNotEmpty)
        .toList();
  }
}

/// Photo viewer dialog
class PhotoViewerDialog extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;

  const PhotoViewerDialog({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<PhotoViewerDialog> createState() => _PhotoViewerDialogState();
}

class _PhotoViewerDialogState extends State<PhotoViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Photos
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                child: Center(
                  child: Image.network(
                    widget.photos[index],
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),

          // Close button
          Positioned(
            top: 50,
            right: 16,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
            ),
          ),

          // Page indicator
          if (widget.photos.length > 1)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.photos.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentIndex == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
