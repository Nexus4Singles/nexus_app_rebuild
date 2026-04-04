import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/theme.dart';
import '../../application/counselling_providers.dart';
import '../../domain/counselling_models.dart';
import 'booking_calendar_screen.dart';

class CoachProfileScreen extends ConsumerStatefulWidget {
  final CoachModel coach;
  final SessionType sessionType;

  const CoachProfileScreen({
    super.key,
    required this.coach,
    required this.sessionType,
  });

  @override
  ConsumerState<CoachProfileScreen> createState() => _CoachProfileScreenState();
}

class _CoachProfileScreenState extends ConsumerState<CoachProfileScreen> {
  late SessionType _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.sessionType;
  }

  @override
  Widget build(BuildContext context) {
    final coach = widget.coach;
    final slotsAsync = ref.watch(availableSlotsProvider(coach.id));
    // Filter by the currently selected session type so the CTA and badge
    // reflect actual availability for that specific session type.
    final filteredSlots =
        slotsAsync.valueOrNull
            ?.where((s) => s.supportsSessionType(_selectedType.firestoreKey))
            .toList();
    final hasAvailableSlots = filteredSlots?.isNotEmpty ?? false;
    final rate = coach.rateForSession(_selectedType.firestoreKey);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.getBackground(context),
        body: CustomScrollView(
          slivers: [
            // ── Hero ──
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.black,
              surfaceTintColor: Colors.transparent,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              leading: Padding(
                padding: const EdgeInsets.all(10),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Photo
                    coach.profilePhotoUrl != null
                        ? CachedNetworkImage(
                          imageUrl: coach.profilePhotoUrl!,
                          fit: BoxFit.cover,
                          errorWidget:
                              (_, __, ___) =>
                                  _HeroPlaceholder(name: coach.name),
                        )
                        : _HeroPlaceholder(name: coach.name),

                    // 3-stop gradient
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.25),
                            Colors.black.withOpacity(0.88),
                          ],
                          stops: const [0.3, 0.6, 1.0],
                        ),
                      ),
                    ),

                    // Name + badges overlay
                    Positioned(
                      bottom: 12,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Verified badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Verified Counselor',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            coach.name,
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            coach.title,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Quick info pills
                          Row(
                            children: [
                              _HeroBadge(
                                icon: Icons.videocam_rounded,
                                label: 'Video Session',
                              ),
                              const SizedBox(width: 8),
                              _HeroBadge(
                                icon: Icons.timer_outlined,
                                label: '60 min',
                              ),
                              const SizedBox(width: 8),
                              _HeroBadge(
                                icon: Icons.language_rounded,
                                label: 'English',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Body ──
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Stats band ──
                  _StatsBand(coach: coach),

                  const SizedBox(height: 16),

                  // About
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(title: 'About'),
                        const SizedBox(height: 8),
                        _AboutCard(bio: coach.bio),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Specializations
                  if (coach.specializations.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeader(title: 'Specializations'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                coach.specializations
                                    .map((s) => _SpecializationChip(label: s))
                                    .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Session types & pricing
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(title: 'Session Types & Pricing'),
                        const SizedBox(height: 8),
                        ...coach.sessionTypes.map((typeKey) {
                          final type = SessionType.fromString(typeKey);
                          final r = coach.rateForSession(typeKey);
                          return _SessionRateRow(
                            sessionType: type,
                            rate: r,
                            currency: coach.currency,
                            isSelected: typeKey == _selectedType.firestoreKey,
                            onTap: () => setState(() => _selectedType = type),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Availability
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(title: 'Availability'),
                        const SizedBox(height: 8),
                        slotsAsync.when(
                          loading: () => const _AvailabilityShimmer(),
                          error:
                              (e, _) =>
                                  _AvailabilityError(message: e.toString()),
                          data: (slots) {
                            final typeSlots =
                                slots
                                    .where(
                                      (s) => s.supportsSessionType(
                                        _selectedType.firestoreKey,
                                      ),
                                    )
                                    .toList();
                            return GestureDetector(
                              onTap:
                                  typeSlots.isNotEmpty
                                      ? () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (_) => BookingCalendarScreen(
                                                coach: coach,
                                                sessionType: _selectedType,
                                              ),
                                        ),
                                      )
                                      : null,
                              child: _AvailabilityBadge(
                                slotCount: typeSlots.length,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 72),
                ],
              ),
            ),
          ],
        ),

        // ── Sticky CTA ──
        bottomNavigationBar: _BottomCTA(
          coach: coach,
          sessionType: _selectedType,
          hasAvailableSlots: hasAvailableSlots,
          rate: rate,
          isDark: isDark,
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBand extends StatelessWidget {
  final CoachModel coach;
  const _StatsBand({required this.coach});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    /// Thresholds: only show stats that have meaningful numbers
    final showRating = coach.totalRatings >= 5;
    final showSessions = coach.totalSessions >= 10;
    final showExperience = coach.yearsOfExperience > 0;

    // If nothing to show, render nothing
    final visibleCards = [
      if (showRating)
        _StatCard(
          value: coach.formattedRating,
          label: '${coach.totalRatings} reviews',
          icon: Icons.star_rounded,
          iconColor: const Color(0xFFFFB800),
          bgColor: const Color(0xFFFFF8E6),
          darkBgColor: const Color(0xFF3A3010),
        ),
      if (showSessions)
        _StatCard(
          value: '${coach.totalSessions}+',
          label: 'Sessions',
          icon: Icons.event_available_rounded,
          iconColor: AppColors.primary,
          bgColor: AppColors.primary.withOpacity(0.1),
          darkBgColor: AppColors.primary.withOpacity(0.2),
        ),
      if (showExperience)
        _StatCard(
          value: '${coach.yearsOfExperience}yr',
          label: 'Experience',
          icon: Icons.workspace_premium_rounded,
          iconColor: const Color(0xFF8B5CF6),
          bgColor: const Color(0xFFF3E8FF),
          darkBgColor: const Color(0xFF2D1F4A),
        ),
    ];

    if (visibleCards.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color:
            isDark
                ? AppColors.primary.withOpacity(0.06)
                : AppColors.primary.withOpacity(0.04),
        border: Border(
          top: BorderSide(color: AppColors.primary.withOpacity(0.1)),
          bottom: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          for (int i = 0; i < visibleCards.length; i++) ...[
            Expanded(child: visibleCards[i]),
            if (i < visibleCards.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color darkBgColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.darkBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withOpacity(0.18)
                    : Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? darkBgColor : bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 14),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 15,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _AboutCard extends StatefulWidget {
  final String bio;
  const _AboutCard({required this.bio});

  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.getTextSecondary(context).withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.bio,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
              height: 1.55,
              fontSize: 13,
            ),
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Show less' : 'Read more',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecializationChip extends StatelessWidget {
  final String label;
  const _SpecializationChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SessionRateRow extends StatelessWidget {
  final SessionType sessionType;
  final double rate;
  final String currency;
  final bool isSelected;
  final VoidCallback? onTap;

  const _SessionRateRow({
    required this.sessionType,
    required this.rate,
    required this.currency,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary.withOpacity(0.06)
                  : AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            width: isSelected ? 1.5 : 1,
            color:
                isSelected
                    ? AppColors.primary.withOpacity(0.5)
                    : AppColors.getTextSecondary(context).withOpacity(0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.primary.withOpacity(0.12)
                        : AppColors.getTextSecondary(context).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                sessionType.icon,
                color:
                    isSelected
                        ? AppColors.primary
                        : AppColors.getTextSecondary(context),
                size: 14,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sessionType.shortLabel,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          isSelected
                              ? AppColors.primary
                              : AppColors.getTextPrimary(context),
                    ),
                  ),
                  Text(
                    sessionType.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$currency ${_fmt(rate)}',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color:
                        isSelected
                            ? AppColors.primary
                            : AppColors.getTextPrimary(context),
                  ),
                ),
                Text(
                  'per hour',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 10,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(double amount) {
    if (amount >= 1000) {
      return '${amount ~/ 1000},${(amount % 1000).toStringAsFixed(0).padLeft(3, '0')}';
    }
    return amount.toStringAsFixed(0);
  }
}

class _AvailabilityError extends StatelessWidget {
  final String message;
  const _AvailabilityError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Could not load availability. Pull to refresh.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  final int slotCount;
  const _AvailabilityBadge({required this.slotCount});

  @override
  Widget build(BuildContext context) {
    final hasSlots = slotCount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (hasSlots ? AppColors.success : AppColors.error).withOpacity(
          0.07,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (hasSlots ? AppColors.success : AppColors.error).withOpacity(
            0.22,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (hasSlots ? AppColors.success : AppColors.error)
                  .withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasSlots
                  ? Icons.event_available_rounded
                  : Icons.event_busy_rounded,
              color: hasSlots ? AppColors.success : AppColors.error,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasSlots ? '$slotCount slots available' : 'No slots available',
                style: AppTextStyles.titleSmall.copyWith(
                  color: hasSlots ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                hasSlots
                    ? 'Select a date & time to book'
                    : 'Check back soon for new openings',
                style: AppTextStyles.bodySmall.copyWith(
                  color: (hasSlots ? AppColors.success : AppColors.error)
                      .withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvailabilityShimmer extends StatelessWidget {
  const _AvailabilityShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _BottomCTA extends StatelessWidget {
  final CoachModel coach;
  final SessionType sessionType;
  final bool hasAvailableSlots;
  final double rate;
  final bool isDark;

  const _BottomCTA({
    required this.coach,
    required this.sessionType,
    required this.hasAvailableSlots,
    required this.rate,
    required this.isDark,
  });

  String _fmt(double amount) {
    if (amount >= 1000) {
      return '${amount ~/ 1000},${(amount % 1000).toStringAsFixed(0).padLeft(3, '0')}';
    }
    return amount.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getBackground(context),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withOpacity(0.4)
                    : Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sessionType.shortLabel,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                            fontSize: 11,
                          ),
                        ),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${coach.currency} ${_fmt(rate)}',
                                style: AppTextStyles.titleLarge.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              TextSpan(
                                text: ' /hr',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (coach.totalSessions >= 10)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            color: AppColors.success,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${coach.totalSessions}+ clients',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      hasAvailableSlots
                          ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => BookingCalendarScreen(
                                    coach: coach,
                                    sessionType: sessionType,
                                  ),
                            ),
                          )
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.getTextSecondary(
                      context,
                    ).withOpacity(0.15),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        hasAvailableSlots
                            ? 'Book a Session'
                            : 'No Available Slots',
                        style: AppTextStyles.titleSmall.copyWith(
                          color:
                              hasAvailableSlots
                                  ? Colors.white
                                  : AppColors.getTextSecondary(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (hasAvailableSlots) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (hasAvailableSlots)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 11,
                        color: AppColors.getTextSecondary(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Free cancellation up to 24h before session',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 10,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  final String name;
  const _HeroPlaceholder({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials =
        name.trim().split(' ').take(2).map((w) {
          return w.isNotEmpty ? w[0].toUpperCase() : '';
        }).join();

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 80,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}
