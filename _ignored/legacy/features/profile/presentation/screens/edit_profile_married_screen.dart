import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/user_provider.dart';

/// Edit Profile Screen for MARRIED users
/// - Basic info only (name, location)
/// - No dating-specific fields (photos, looking for, hobbies, church, etc.)
/// Theme: Red/White consistent with app branding
class EditProfileMarriedScreen extends ConsumerStatefulWidget {
  const EditProfileMarriedScreen({super.key});

  @override
  ConsumerState<EditProfileMarriedScreen> createState() => _EditProfileMarriedScreenState();
}

class _EditProfileMarriedScreenState extends ConsumerState<EditProfileMarriedScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  
  // State
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;

  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadUserData();
  }

  @override
  void dispose() {
    _animController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null) {
      _displayNameController.text = user.displayName;
      _usernameController.text = user.username ?? '';
      _cityController.text = user.profile?.city ?? '';
      _stateController.text = user.profile?.stateOfResidence ?? '';
    }
    
    setState(() => _isLoading = false);
    _animController.forward();
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);

    try {
      final updates = <String, dynamic>{
        'displayName': _displayNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'profile.city': _cityController.text.trim(),
        'profile.stateOfResidence': _stateController.text.trim(),
      };

      await ref.read(userNotifierProvider.notifier).updateProfile(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeIn,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Premium App Bar - Red/White theme
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              leading: IconButton(
                onPressed: () => _confirmExit(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              actions: [
                if (_hasChanges)
                  TextButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(60, 16, 20, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Update your basic information',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Form Content
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(
                child: Form(
                  key: _formKey,
                  onChanged: _markChanged,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info Section
                      _buildSectionHeader('Basic Information', Icons.person_outline),
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _displayNameController,
                        label: 'Display Name',
                        hint: 'Your name',
                        icon: Icons.badge_outlined,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _usernameController,
                        label: 'Username',
                        hint: 'Choose a username',
                        icon: Icons.alternate_email,
                        prefixText: '@',
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter a username';
                          }
                          if (v.length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Location Section
                      _buildSectionHeader('Location', Icons.location_on_outlined),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _cityController,
                        label: 'City',
                        hint: 'Your city',
                        icon: Icons.location_city,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _stateController,
                        label: 'State',
                        hint: 'Your state/region',
                        icon: Icons.map_outlined,
                      ),
                      const SizedBox(height: 32),

                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.favorite,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Married Profile',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Your profile is focused on marriage enrichment. Dating features are not available.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? prefixText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMuted),
            prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
            prefixText: prefixText,
            filled: true,
            fillColor: AppColors.surfaceLight,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmExit(BuildContext context) {
    if (!_hasChanges) {
      context.pop();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Discard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
