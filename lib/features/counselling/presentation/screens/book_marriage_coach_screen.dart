import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/safe_nav.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../features/counselling/domain/counselling_models.dart';
import 'coach_application_screen.dart';
import 'coach_list_screen.dart';
import 'coach_requirements_screen.dart';
import 'my_bookings_screen.dart';

// Counseling type model
class CounselingType {
  final String title;
  final String type; // 'online' or 'physical'
  final IconData icon;
  final String
  category; // 'Individual', 'Couple', 'Premarital', 'PostMarital', 'Parental'

  const CounselingType({
    required this.title,
    required this.type,
    required this.icon,
    required this.category,
  });
}

final counselingTypesProvider = Provider<List<CounselingType>>((ref) {
  return [
    const CounselingType(
      title: 'Individual\nCounseling',
      type: 'Online',
      icon: Icons.person_outline,
      category: 'Individual',
    ),
    const CounselingType(
      title: 'Premarital\nCounseling',
      type: 'Online',
      icon: Icons.favorite_border_outlined,
      category: 'Premarital',
    ),
    const CounselingType(
      title: 'Post Marital\nCounseling',
      type: 'Online',
      icon: Icons.home_outlined,
      category: 'PostMarital',
    ),
    const CounselingType(
      title: 'Parental\nCounseling',
      type: 'Online',
      icon: Icons.family_restroom,
      category: 'Parental',
    ),
  ];
});

class BookMarriageCoachScreen extends ConsumerStatefulWidget {
  const BookMarriageCoachScreen({super.key});

  @override
  ConsumerState<BookMarriageCoachScreen> createState() =>
      _BookMarriageCoachScreenState();
}

class _BookMarriageCoachScreenState
    extends ConsumerState<BookMarriageCoachScreen> {
  int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final counselingTypes = ref.watch(counselingTypesProvider);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            navigateBackToHome(context);
          },
        ),
        title: Text(
          'Speak to a Marriage Coach',
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'My Bookings',
            onPressed:
                () => Navigator.of(context).pushNamed(AppRoutes.myBookings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: const Icon(
                      Icons.waving_hand_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expert Guidance for Your Relationship',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Connect with licensed marriage coaches or family therapists to strengthen your relationship or marriage and overcome challenges together.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Counseling Types Section
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Your Counseling Type',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select the type of counseling that best fits your needs',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Counseling Cards Grid - 2 per line, centered
                  Center(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.3,
                          ),
                      itemCount: counselingTypes.length,
                      itemBuilder: (context, index) {
                        final counseling = counselingTypes[index];
                        final isSelected = selectedIndex == index;

                        return _CounselingCard(
                          counseling: counseling,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              selectedIndex = isSelected ? null : index;
                            });
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Info Box - MOVED BEFORE BUTTON
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'All coaches are verified and licensed professionals',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextSecondary(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          selectedIndex != null
                              ? () {
                                final categories = [
                                  SessionType.individual,
                                  SessionType.premarital,
                                  SessionType.postMarital,
                                  SessionType.parenting,
                                ];
                                final sessionType =
                                    categories[selectedIndex!];
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CoachListScreen(
                                          sessionType: sessionType,
                                        ),
                                  ),
                                );
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primary.withOpacity(
                          0.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Book a Session',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Professional Recruitment Section
                  _buildRecruitmentSection(context),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecruitmentSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.12),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.business_center_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Call for Applications',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Join our Counselling Team',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            'Are you a licensed marriage counselor, relationship coach or family therapist? Enroll as one of our experienced professionals providing expert guidance to people who need help navigating life, relationships, marriage or even parenting.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.getTextSecondary(context),
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          // Benefits List
          ...[
            ('Flexible Schedule', 'Set your own availability and rates'),
            ('Professional Growth', 'Build your coaching practice'),
            ('Earn Per Session', 'You get paid for every session with clients'),
          ].map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          item.$2,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          const SizedBox(height: 20),

          // CTA Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CoachRequirementsScreen(),
                    ),
                  ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(
                'Submit Your Application',
                style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CounselingCard extends StatelessWidget {
  final CounselingType counseling;
  final bool isSelected;
  final VoidCallback onTap;

  const _CounselingCard({
    required this.counseling,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? AppColors.primary : AppColors.getBorder(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon Container - push to top
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                counseling.icon,
                color: isSelected ? Colors.white : AppColors.primary,
                size: 16,
              ),
            ),

            // Title - centered
            Text(
              counseling.title,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Type Badge - push to bottom
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: _getTypeColor(
                  counseling.type,
                  context,
                ).withOpacity(0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                counseling.type,
                style: AppTextStyles.labelSmall.copyWith(
                  color: _getTypeColor(counseling.type, context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Selection Indicator
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type, BuildContext context) {
    if (type == 'Online') {
      return const Color(0xFF4CAF50);
    } else {
      return const Color(0xFF2196F3);
    }
  }
}
