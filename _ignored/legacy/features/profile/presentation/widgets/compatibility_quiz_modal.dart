import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';

/// Compatibility Quiz Modal - Enforced after dating profile completion
/// Cannot be skipped - user must complete before accessing full app features
class CompatibilityQuizModal extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const CompatibilityQuizModal({super.key, required this.onComplete});

  /// Show as fullscreen modal (cannot be dismissed)
  static Future<void> show(BuildContext context, {required VoidCallback onComplete}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CompatibilityQuizModal(onComplete: onComplete),
    );
  }

  @override
  ConsumerState<CompatibilityQuizModal> createState() => _CompatibilityQuizModalState();
}

class _CompatibilityQuizModalState extends ConsumerState<CompatibilityQuizModal> {
  bool _showIntro = true;
  bool _showThankYou = false;
  final Map<String, String> _answers = {};
  final ScrollController _scrollController = ScrollController();

  // Questions based on Nexus 1.0 compatibility quiz
  static const _questions = [
    {
      'key': 'maritalStatus',
      'question': '1. What is your Marital Status?',
      'options': ['Never Married', 'Divorced', 'Widow/Widower'],
    },
    {
      'key': 'haveKids',
      'question': '2. Do you have kids?',
      'options': ['Yes', 'No'],
    },
    {
      'key': 'genotype',
      'question': '3. What is your Genotype?',
      'options': ['AA', 'AC', 'AS', 'SS'],
    },
    {
      'key': 'personalityType',
      'question': '4. What is your Personality type?',
      'options': ['Ambivert', 'Extrovert', 'Introvert'],
    },
    {
      'key': 'regularSourceOfIncome',
      'question': '5. Do you have a regular source of Income?',
      'options': ['Yes', 'No'],
    },
    {
      'key': 'marrySomeoneNotFS',
      'question': '6. Can you date or marry someone who is not yet financially stable?',
      'options': [
        'Yes, as long as they are diligent & responsible',
        'No, due to reasons that are important to me',
      ],
    },
    {
      'key': 'longDistance',
      'question': '7. Are you open to a long distance relationship?',
      'options': ['Yes', 'No'],
    },
    {
      'key': 'believeInCohabiting',
      'question': '8. Do you believe in cohabiting before marriage?',
      'options': [
        'Yes, it is necessary to know my partner well',
        'No, I don\'t believe in it at all',
      ],
    },
    {
      'key': 'shouldChristianSpeakInTongue',
      'question': '9. Do you think every Christian should desire to speak in tongues?',
      'options': ['Yes', 'No', 'I\'m not sure'],
    },
    {
      'key': 'believeInTithing',
      'question': '10. Do you believe in Tithing?',
      'options': ['Yes', 'No'],
    },
  ];

  bool get _isComplete => _answers.length == _questions.length;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showThankYou) {
      return _buildThankYouScreen();
    }
    
    if (_showIntro) {
      return _buildIntroScreen();
    }
    
    return _buildQuizScreen();
  }

  Widget _buildIntroScreen() {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebration icon
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/images/celebration.png',
                width: 80,
                height: 80,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.celebration,
                  size: 64,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(
              'Compatibility Quiz',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),

            Text(
              'Please take one (1) minute to answer these questions to help us know more about you',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),

            AppButton.primary(
              label: 'Start',
              onPressed: () => setState(() => _showIntro = false),
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizScreen() {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Compatibility Quiz'),
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            // Info banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              color: AppColors.primary.withOpacity(0.1),
              child: Text(
                'Kindly answer the questions below. Your responses will not be visible on your profile. It will only be visible to your matched users to provide them with more information on their compatibility with you.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                    ),
                textAlign: TextAlign.center,
              ),
            ),

            // Questions
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final q = _questions[index];
                  return _buildQuestionCard(
                    question: q['question'] as String,
                    options: q['options'] as List<String>,
                    key: q['key'] as String,
                    selectedValue: _answers[q['key']],
                  );
                },
              ),
            ),

            // Submit button
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppButton.primary(
                label: 'Submit',
                onPressed: _isComplete ? _submitQuiz : null,
                isExpanded: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard({
    required String question,
    required List<String> options,
    required String key,
    String? selectedValue,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...options.map((option) {
            final isSelected = selectedValue == option;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: InkWell(
                onTap: () {
                  setState(() => _answers[key] = option);
                },
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: 2,
                          ),
                          color: isSelected ? AppColors.primary : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          option,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildThankYouScreen() {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                children: [
                  Text(
                    'Thanks for your response!!',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Only matched users will be able to see your responses. You will also be able to see the button to view their own responses, when you scroll down to the end of their profiles.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            AppButton.primary(
              label: 'Continue',
              onPressed: () {
                Navigator.of(context).pop();
                widget.onComplete();
              },
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitQuiz() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    try {
      // Save compatibility data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'compatibility': _answers,
        'compatibilitySetted': true,
        'compatibilityCompletedAt': FieldValue.serverTimestamp(),
      });

      HapticFeedback.mediumImpact();
      
      // Refresh user data
      ref.invalidate(currentUserProvider);
      
      setState(() => _showThankYou = true);
    } catch (e) {
      debugPrint('Error saving compatibility data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

/// Provider to check if user needs to complete compatibility quiz
final needsCompatibilityQuizProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return false;
  
  // Check if user is single and hasn't completed compatibility quiz
  if (!user.isSingle) return false;
  
  final compatibilitySetted = user.toMap()['compatibilitySetted'] as bool? ?? false;
  return !compatibilitySetted;
});

/// Widget to show compatibility data on profile
class CompatibilityDataViewer extends StatelessWidget {
  final Map<String, dynamic> compatibilityData;

  const CompatibilityDataViewer({super.key, required this.compatibilityData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Compatibility Data',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          _buildDataRow(context, 'Marital Status', compatibilityData['maritalStatus']),
          _buildDataRow(context, 'Has Kids', compatibilityData['haveKids']),
          _buildDataRow(context, 'Genotype', compatibilityData['genotype']),
          _buildDataRow(context, 'Personality Type', compatibilityData['personalityType']),
          _buildDataRow(context, 'Regular Income', compatibilityData['regularSourceOfIncome']),
          _buildDataRow(context, 'Date someone not financially stable', compatibilityData['marrySomeoneNotFS']),
          _buildDataRow(context, 'Open to Long Distance', compatibilityData['longDistance']),
          _buildDataRow(context, 'Believes in Cohabiting', compatibilityData['believeInCohabiting']),
          _buildDataRow(context, 'Speaking in Tongues', compatibilityData['shouldChristianSpeakInTongue']),
          _buildDataRow(context, 'Believes in Tithing', compatibilityData['believeInTithing']),
        ],
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? 'Not provided',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Button to show compatibility data (for matched users only)
class ViewCompatibilityButton extends StatelessWidget {
  final Map<String, dynamic> compatibilityData;

  const ViewCompatibilityButton({super.key, required this.compatibilityData});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: CompatibilityDataViewer(compatibilityData: compatibilityData),
            ),
          ),
        );
      },
      icon: const Icon(Icons.psychology),
      label: const Text('View Compatibility Data'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.secondary,
        side: BorderSide(color: AppColors.secondary),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}
