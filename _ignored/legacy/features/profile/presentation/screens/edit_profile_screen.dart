import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/media_service.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Edit Profile Screen for dating users
/// - Cannot edit audio recordings
/// - First photo = profile icon
/// - Minimum 1 photo required
/// - Face detection for photo validation
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Form controllers
  final _usernameController = TextEditingController();
  final _ageController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _professionController = TextEditingController();
  final _churchController = TextEditingController();
  final _aboutController = TextEditingController();
  final _lookingForController = TextEditingController();
  
  // Social media controllers
  final _instagramController = TextEditingController();
  final _twitterController = TextEditingController();
  final _facebookController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _telegramController = TextEditingController();
  final _snapchatController = TextEditingController();
  
  // State
  List<String> _photos = [];
  List<String> _hobbies = [];
  List<String> _desiredQualities = [];
  String? _educationLevel;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasChanges = false;
  
  // Face detection
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
      enableLandmarks: false,
      enableTracking: false,
      minFaceSize: 0.1,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  // Audio player for previewing recordings
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingAudioIndex;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserData();
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playingAudioIndex = null;
          _isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _ageController.dispose();
    _nationalityController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _professionController.dispose();
    _churchController.dispose();
    _aboutController.dispose();
    _lookingForController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _facebookController.dispose();
    _whatsappController.dispose();
    _telegramController.dispose();
    _snapchatController.dispose();
    _faceDetector.close();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    setState(() {
      _usernameController.text = user.username ?? '';
      _ageController.text = user.age?.toString() ?? '';
      _nationalityController.text = user.nationality ?? '';
      _cityController.text = user.city ?? '';
      _countryController.text = user.country ?? '';
      _professionController.text = user.profession ?? '';
      _churchController.text = user.churchName ?? '';
      _aboutController.text = user.bestQualitiesOrTraits ?? '';
      _lookingForController.text = user.desiredQualities ?? '';
      _educationLevel = user.educationLevel;
      
      // Load photos - profileUrl first, then additional photos
      _photos = [];
      if (user.profileUrl != null && user.profileUrl!.isNotEmpty) {
        _photos.add(user.profileUrl!);
      }
      if (user.photos != null) {
        for (final photo in user.photos!) {
          if (!_photos.contains(photo) && photo.isNotEmpty) {
            _photos.add(photo);
          }
        }
      }
      
      // Load hobbies
      _hobbies = List<String>.from(user.hobbies ?? []);
      
      // Load desired qualities (parse from string if needed)
      if (user.desiredQualities != null) {
        _desiredQualities = user.desiredQualities!
            .split(RegExp(r'[,\n]'))
            .map((q) => q.trim())
            .where((q) => q.isNotEmpty)
            .toList();
      }
      
      // Load social media
      _instagramController.text = user.instagramUsername ?? '';
      _twitterController.text = user.twitterUsername ?? '';
      _facebookController.text = user.facebookUsername ?? '';
      _whatsappController.text = user.phoneNumber ?? '';
      _telegramController.text = user.telegramUsername ?? '';
      _snapchatController.text = user.snapchatUsername ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Premium App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              onPressed: () => _handleBack(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
            actions: [
              if (_hasChanges)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : TextButton(
                          onPressed: () => _saveProfile(context),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(60, 16, 20, 60),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Update your dating profile',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                color: AppColors.background,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Photos'),
                    Tab(text: 'About'),
                    Tab(text: 'Interests'),
                    Tab(text: 'Contact'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPhotosTab(user),
            _buildAboutTab(user),
            _buildInterestsTab(),
            _buildContactTab(user),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // PHOTOS TAB
  // ============================================================================

  Widget _buildPhotosTab(UserModel? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile photo (first photo)
          _buildSectionTitle('Profile Photo'),
          const SizedBox(height: 8),
          Text(
            'Your first photo will be your profile picture',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Photo grid
          _buildPhotoGrid(),
          const SizedBox(height: 24),

          // Audio recordings (read-only)
          _buildSectionTitle('Voice Prompts'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.textMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Audio recordings cannot be changed after profile creation',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Show existing audio recordings (playback only)
          _buildAudioRecordings(user),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: 6, // Max 6 photos
      itemBuilder: (context, index) {
        if (index < _photos.length) {
          return _buildPhotoTile(index, _photos[index]);
        }
        return _buildAddPhotoTile(index);
      },
    );
  }

  Widget _buildPhotoTile(int index, String photoUrl) {
    final isProfilePhoto = index == 0;
    
    return Stack(
      children: [
        // Photo
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isProfilePhoto
                ? Border.all(color: AppColors.primary, width: 3)
                : null,
            image: DecorationImage(
              image: NetworkImage(photoUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        
        // Profile badge
        if (isProfilePhoto)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        
        // Delete button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => _deletePhoto(index),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
        
        // Reorder hint
        if (!isProfilePhoto)
          Positioned(
            bottom: 8,
            left: 8,
            child: GestureDetector(
              onTap: () => _makeProfilePhoto(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Make profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddPhotoTile(int index) {
    return GestureDetector(
      onTap: () => _addPhoto(index),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: AppColors.textMuted,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Add Photo',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioRecordings(UserModel? user) {
    final audioPrompts = [
      {'title': 'My relationship with God', 'key': 'audio1Url'},
      {'title': 'My view on gender roles', 'key': 'audio2Url'},
      {'title': 'Favourite traits about myself', 'key': 'audio3Url'},
    ];

    // Get audio URLs from user's dating profile data
    String? audio1Url;
    String? audio2Url;
    String? audio3Url;
    
    if (user != null) {
      // Check datingProfile first
      final datingProfile = user.toMap()['datingProfile'] as Map<String, dynamic>?;
      if (datingProfile != null) {
        final audio = datingProfile['audio'] as Map<String, dynamic>?;
        if (audio != null) {
          audio1Url = audio['audio1Url'] as String?;
          audio2Url = audio['audio2Url'] as String?;
          audio3Url = audio['audio3Url'] as String?;
        }
      }
      // Fallback to top-level fields
      audio1Url ??= user.toMap()['audio1Url'] as String?;
      audio2Url ??= user.toMap()['audio2Url'] as String?;
      audio3Url ??= user.toMap()['audio3Url'] as String?;
    }
    
    final audioUrls = [audio1Url, audio2Url, audio3Url];

    return Column(
      children: audioPrompts.asMap().entries.map((entry) {
        final index = entry.key;
        final prompt = entry.value;
        final audioUrl = audioUrls[index];
        
        return _buildAudioItem(
          title: prompt['title']!,
          index: index,
          audioUrl: audioUrl,
        );
      }).toList(),
    );
  }

  Widget _buildAudioItem({
    required String title,
    required int index,
    String? audioUrl,
  }) {
    final isPlaying = _playingAudioIndex == index && _isPlaying;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Play button
          GestureDetector(
            onTap: audioUrl != null ? () => _toggleAudio(index, audioUrl) : null,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: audioUrl != null 
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.surfaceDark,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: audioUrl != null ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  audioUrl != null ? 'Tap to play' : 'Not recorded',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Lock icon (cannot edit)
          Icon(
            Icons.lock_outline,
            color: AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // ABOUT TAB
  // ============================================================================

  Widget _buildAboutTab(UserModel? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Username
          AppTextField(
            controller: _usernameController,
            label: 'Display Name',
            hint: 'How others will see your name',
            onChanged: (_) => _markAsChanged(),
          ),
          const SizedBox(height: 20),

          // Age
          AppTextField(
            controller: _ageController,
            label: 'Age',
            hint: 'Your age',
            keyboardType: TextInputType.number,
            onChanged: (_) => _markAsChanged(),
          ),
          const SizedBox(height: 20),

          // Nationality
          AppTextField(
            controller: _nationalityController,
            label: 'Nationality',
            hint: 'e.g. Nigerian',
            onChanged: (_) => _markAsChanged(),
          ),
          const SizedBox(height: 20),

          // Location
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _cityController,
                  label: 'City',
                  hint: 'e.g. Lagos',
                  onChanged: (_) => _markAsChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _countryController,
                  label: 'Country',
                  hint: 'e.g. Nigeria',
                  onChanged: (_) => _markAsChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Education
          _buildSectionTitle('Education Level'),
          const SizedBox(height: 8),
          _buildEducationDropdown(),
          const SizedBox(height: 20),

          // Profession
          AppTextField(
            controller: _professionController,
            label: 'Profession',
            hint: 'e.g. Software Engineer',
            onChanged: (_) => _markAsChanged(),
          ),
          const SizedBox(height: 20),

          // Church
          AppTextField(
            controller: _churchController,
            label: 'Church (Optional)',
            hint: 'Your place of worship',
            onChanged: (_) => _markAsChanged(),
          ),
          const SizedBox(height: 20),

          // About me
          AppTextField(
            controller: _aboutController,
            label: 'About Me',
            hint: 'Tell others about yourself...',
            maxLines: 4,
            onChanged: (_) => _markAsChanged(),
          ),
          const SizedBox(height: 20),

          // Looking for
          AppTextField(
            controller: _lookingForController,
            label: 'What I\'m Looking For',
            hint: 'Describe your ideal partner...',
            maxLines: 4,
            onChanged: (_) => _markAsChanged(),
          ),
          const SizedBox(height: 40),

          // Switch to Married section
          _buildSwitchToMarriedSection(),
        ],
      ),
    );
  }

  Widget _buildEducationDropdown() {
    final levels = [
      'High School',
      'Diploma',
      'Bachelor\'s Degree',
      'Master\'s Degree',
      'Doctorate Degree',
      'Other',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _educationLevel,
          isExpanded: true,
          hint: Text(
            'Select education level',
            style: TextStyle(color: AppColors.textMuted),
          ),
          items: levels.map((level) {
            return DropdownMenuItem(
              value: level,
              child: Text(level),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _educationLevel = value;
              _hasChanges = true;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSwitchToMarriedSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, color: AppColors.secondary),
              const SizedBox(width: 12),
              const Text(
                'Got Married?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Congratulations! 🎉 If you\'ve found your partner, you can switch to the Married section to access marriage resources and connect with other married couples.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showSwitchToMarriedDialog(context),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Switch to Married'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: BorderSide(color: AppColors.secondary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // INTERESTS TAB
  // ============================================================================

  Widget _buildInterestsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hobbies
          _buildSectionTitle('Hobbies & Interests'),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Select up to 5 hobbies',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _hobbies.isNotEmpty ? AppColors.primarySoft : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_hobbies.length}/5',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _hobbies.isNotEmpty ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildHobbiesChips(),
          const SizedBox(height: 32),

          // Desired qualities
          _buildSectionTitle('Most Desired Qualities'),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Select up to 8 qualities you want in a partner',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _desiredQualities.isNotEmpty ? AppColors.primarySoft : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_desiredQualities.length}/8',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _desiredQualities.isNotEmpty ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildQualitiesChips(),
        ],
      ),
    );
  }

  Widget _buildHobbiesChips() {
    final allHobbies = [
      'Reading', 'Music', 'Travel', 'Sports', 'Cooking',
      'Photography', 'Gaming', 'Movies', 'Art', 'Writing',
      'Fitness', 'Dancing', 'Hiking', 'Gardening', 'Volunteering',
      'Wine', 'Books', 'Tech', 'Fashion', 'Nature',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: allHobbies.map((hobby) {
        final isSelected = _hobbies.contains(hobby);
        return _SelectableChip(
          label: hobby,
          isSelected: isSelected,
          onTap: () => _toggleHobby(hobby),
        );
      }).toList(),
    );
  }

  Widget _buildQualitiesChips() {
    final allQualities = [
      'Honest', 'Kind', 'Ambitious', 'Faithful', 'Compassionate',
      'Intelligent', 'Humorous', 'Patient', 'Supportive', 'Respectful',
      'Diligent', 'Empathy', 'Self Control', 'Thoughtfulness', 'Loyal',
      'Caring', 'Understanding', 'Romantic', 'Family-oriented', 'Spiritual',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: allQualities.map((quality) {
        final isSelected = _desiredQualities.contains(quality);
        return _SelectableChip(
          label: quality,
          isSelected: isSelected,
          onTap: () => _toggleQuality(quality),
          color: AppColors.secondary,
        );
      }).toList(),
    );
  }

  // ============================================================================
  // CONTACT TAB
  // ============================================================================

  Widget _buildContactTab(UserModel? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Social Media'),
          const SizedBox(height: 8),
          Text(
            'Add at least one way for matches to contact you',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),

          _buildSocialField(
            controller: _instagramController,
            label: 'Instagram',
            icon: Icons.camera_alt,
            hint: '@username',
            color: const Color(0xFFE4405F),
          ),
          const SizedBox(height: 16),

          _buildSocialField(
            controller: _twitterController,
            label: 'Twitter / X',
            icon: Icons.alternate_email,
            hint: '@username',
            color: const Color(0xFF1DA1F2),
          ),
          const SizedBox(height: 16),

          _buildSocialField(
            controller: _whatsappController,
            label: 'WhatsApp',
            icon: Icons.phone,
            hint: '+234...',
            color: const Color(0xFF25D366),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          _buildSocialField(
            controller: _facebookController,
            label: 'Facebook',
            icon: Icons.facebook,
            hint: 'Username or profile link',
            color: const Color(0xFF1877F2),
          ),
          const SizedBox(height: 16),

          _buildSocialField(
            controller: _telegramController,
            label: 'Telegram',
            icon: Icons.send,
            hint: '@username',
            color: const Color(0xFF0088CC),
          ),
          const SizedBox(height: 16),

          _buildSocialField(
            controller: _snapchatController,
            label: 'Snapchat',
            icon: Icons.snapchat,
            hint: 'Username',
            color: const Color(0xFFFFFC00),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    required Color color,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
            ),
            child: Icon(
              icon,
              color: color == const Color(0xFFFFFC00) ? Colors.black : color,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (_) => _markAsChanged(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPER WIDGETS
  // ============================================================================

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // ACTIONS
  // ============================================================================

  void _markAsChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  void _toggleHobby(String hobby) {
    setState(() {
      if (_hobbies.contains(hobby)) {
        _hobbies.remove(hobby);
      } else if (_hobbies.length < 5) {
        _hobbies.add(hobby);
      } else {
        _showSnackbar('You can only select up to 5 hobbies');
        return;
      }
      _hasChanges = true;
    });
  }

  void _toggleQuality(String quality) {
    setState(() {
      if (_desiredQualities.contains(quality)) {
        _desiredQualities.remove(quality);
      } else if (_desiredQualities.length < 8) { // Max 8 qualities
        _desiredQualities.add(quality);
      } else {
        _showSnackbar('You can only select up to 8 qualities');
        return;
      }
      _hasChanges = true;
    });
  }

  Future<void> _addPhoto(int index) async {
    final mediaService = ref.read(mediaServiceProvider);
    
    try {
      // Pick image
      final file = await mediaService.pickImage(context);
      if (file == null) return;

      // Show loading
      setState(() => _isLoading = true);

      // Validate face detection
      final hasHumanFace = await _validateHumanFace(file);
      if (!hasHumanFace) {
        setState(() => _isLoading = false);
        _showErrorDialog(
          'Invalid Photo',
          'Please upload a photo of yourself. We couldn\'t detect a human face in this image.',
        );
        return;
      }

      // Upload photo
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      final url = await mediaService.uploadProfilePhoto(
        userId,
        file,
        photoIndex: _photos.length,
      );

      setState(() {
        _photos.add(url);
        _hasChanges = true;
        _isLoading = false;
      });

      _showSnackbar('Photo added successfully');
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar('Failed to add photo: $e');
    }
  }

  Future<bool> _validateHumanFace(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector.processImage(inputImage);
      return faces.isNotEmpty;
    } catch (e) {
      debugPrint('Face detection error: $e');
      // If face detection fails, allow the photo (fail open)
      return true;
    }
  }

  void _deletePhoto(int index) {
    // Check if this is the last photo
    if (_photos.length <= 1) {
      _showErrorDialog(
        'Cannot Delete',
        'You must have at least one photo on your profile.',
      );
      return;
    }

    setState(() {
      _photos.removeAt(index);
      _hasChanges = true;
    });

    _showSnackbar('Photo deleted');
  }

  void _makeProfilePhoto(int index) {
    if (index == 0) return; // Already profile photo

    setState(() {
      final photo = _photos.removeAt(index);
      _photos.insert(0, photo);
      _hasChanges = true;
    });

    _showSnackbar('Profile photo updated');
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
      setState(() => _playingAudioIndex = index);
    }
  }

  void _showSwitchToMarriedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.favorite, color: AppColors.secondary),
            const SizedBox(width: 12),
            const Text('Switch to Married'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildBulletPoint('Remove you from the singles section'),
            _buildBulletPoint('Give you access to married features'),
            _buildBulletPoint('Show you marriage resources & content'),
            _buildBulletPoint('Connect you with other married couples'),
            const SizedBox(height: 16),
            Text(
              'You can switch back if needed.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _switchToMarried();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            child: const Text('Switch Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Future<void> _switchToMarried() async {
    try {
      setState(() => _isSaving = true);

      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      final firestoreService = ref.read(firestoreServiceProvider);
      
      // Update relationship status to married
      await firestoreService.updateUserFields(userId, {
        'nexus2.relationshipStatus': 'married',
        'nexus2.updatedAt': DateTime.now().toIso8601String(),
      });

      // Refresh user data
      ref.invalidate(currentUserProvider);

      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackbar('Welcome to the married section! 🎉');
        
        // Navigate to married home
        context.go('/home');
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackbar('Failed to switch: $e');
    }
  }

  Future<void> _saveProfile(BuildContext context) async {
    if (!_hasChanges) return;

    setState(() => _isSaving = true);

    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) throw Exception('Not logged in');

      final firestoreService = ref.read(firestoreServiceProvider);

      // Build update data
      final updateData = <String, dynamic>{
        'username': _usernameController.text.trim(),
        'name': _usernameController.text.trim(),
        'age': int.tryParse(_ageController.text),
        'nationality': _nationalityController.text.trim(),
        'city': _cityController.text.trim(),
        'country': _countryController.text.trim(),
        'educationLevel': _educationLevel,
        'profession': _professionController.text.trim(),
        'churchName': _churchController.text.trim(),
        'bestQualitiesOrTraits': _aboutController.text.trim(),
        'desiredQualities': _lookingForController.text.trim(),
        'hobbies': _hobbies,
        
        // First photo is profile URL
        'profileUrl': _photos.isNotEmpty ? _photos.first : null,
        'photos': _photos,
        
        // Social media
        'instagramUsername': _instagramController.text.trim().isEmpty 
            ? null : _instagramController.text.trim(),
        'twitterUsername': _twitterController.text.trim().isEmpty 
            ? null : _twitterController.text.trim(),
        'facebookUsername': _facebookController.text.trim().isEmpty 
            ? null : _facebookController.text.trim(),
        'phoneNumber': _whatsappController.text.trim().isEmpty 
            ? null : _whatsappController.text.trim(),
        'telegramUsername': _telegramController.text.trim().isEmpty 
            ? null : _telegramController.text.trim(),
        'snapchatUsername': _snapchatController.text.trim().isEmpty 
            ? null : _snapchatController.text.trim(),
        
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await firestoreService.updateUserFields(userId, updateData);

      // Refresh user data
      ref.invalidate(currentUserProvider);

      setState(() {
        _isSaving = false;
        _hasChanges = false;
      });

      _showSnackbar('Profile updated successfully!');
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackbar('Failed to save: $e');
    }
  }

  void _handleBack(BuildContext context) {
    if (_hasChanges) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard Changes?'),
          content: const Text('You have unsaved changes. Are you sure you want to leave?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop();
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
    } else {
      context.pop();
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SELECTABLE CHIP WIDGET
// ============================================================================

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _SelectableChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : AppColors.surface,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? chipColor : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: chipColor.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
