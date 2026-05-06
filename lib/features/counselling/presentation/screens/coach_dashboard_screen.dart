import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme.dart';
import '../../application/booking_service.dart';
import '../../application/counselling_providers.dart';
import '../../domain/counselling_models.dart';
import 'coach_availability_screen.dart';
import 'coach_requirements_screen.dart';

class CoachDashboardScreen extends ConsumerWidget {
  const CoachDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myCoachAsync = ref.watch(myCoachProfileProvider);

    return myCoachAsync.when(
      loading:
          () => Scaffold(
            backgroundColor: AppColors.getBackground(context),
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
      error:
          (err, _) => Scaffold(
            backgroundColor: AppColors.getBackground(context),
            body: Center(child: Text('Error: $err')),
          ),
      data: (coach) {
        if (coach == null) {
          return _NotACoachScreen();
        }
        return _CoachDashboard(coach: coach);
      },
    );
  }
}

class _CoachDashboard extends ConsumerWidget {
  final CoachModel coach;

  const _CoachDashboard({required this.coach});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(coachBookingsProvider(coach.id));
    final slotsAsync = ref.watch(allCoachSlotsProvider(coach.id));

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: CustomScrollView(
        slivers: [
          // ── Header ──
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: AppColors.getBackground(context),
            surfaceTintColor: AppColors.getBackground(context),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            backgroundImage:
                                coach.profilePhotoUrl != null
                                    ? NetworkImage(coach.profilePhotoUrl!)
                                    : null,
                            child:
                                coach.profilePhotoUrl == null
                                    ? Text(
                                      coach.name.substring(0, 1).toUpperCase(),
                                      style: AppTextStyles.titleLarge.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                    : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Welcome back,',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.white.withOpacity(0.85),
                                  ),
                                ),
                                Text(
                                  coach.name,
                                  style: AppTextStyles.titleLarge.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFFB800),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  coach.formattedRating,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Stats row
                bookingsAsync.when(
                  loading: () => const SizedBox(height: 80),
                  error: (_, __) => const SizedBox.shrink(),
                  data:
                      (bookings) => _StatsRow(coach: coach, bookings: bookings),
                ),

                const SizedBox(height: 24),

                // Quick actions
                _SectionTitle(title: 'Quick Actions'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.calendar_month_rounded,
                        label: 'Manage\nAvailability',
                        color: AppColors.primary,
                        onTap:
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        CoachAvailabilityScreen(coach: coach),
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.list_alt_rounded,
                        label: 'View All\nBookings',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => _showAllBookings(context, ref, coach.id),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Upcoming bookings
                _SectionTitle(title: 'Upcoming Sessions'),
                const SizedBox(height: 12),

                bookingsAsync.when(
                  loading:
                      () => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                  error: (err, _) => Text('Error loading bookings: $err'),
                  data: (bookings) {
                    final now = DateTime.now();
                    final upcoming =
                        bookings
                            .where(
                              (b) =>
                                  b.scheduledDateTime.isAfter(now) &&
                                  b.bookingStatus == BookingStatus.confirmed,
                            )
                            .take(5)
                            .toList();

                    if (upcoming.isEmpty) {
                      return _EmptySection(
                        icon: Icons.event_available_rounded,
                        message: 'No upcoming confirmed sessions',
                      );
                    }

                    return Column(
                      children:
                          upcoming
                              .map(
                                (b) => _CoachBookingTile(
                                  booking: b,
                                  onMarkComplete:
                                      () => _markComplete(context, ref, b),
                                ),
                              )
                              .toList(),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Upcoming availability
                _SectionTitle(title: 'Your Available Slots'),
                const SizedBox(height: 12),

                slotsAsync.when(
                  loading: () => const SizedBox(height: 60),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (slots) {
                    final available =
                        slots.where((s) => !s.isBooked).take(5).toList();
                    if (available.isEmpty) {
                      return _EmptySection(
                        icon: Icons.calendar_today_outlined,
                        message: 'No open slots added yet',
                        action: 'Add availability',
                        onAction:
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        CoachAvailabilityScreen(coach: coach),
                              ),
                            ),
                      );
                    }
                    return Column(
                      children:
                          available.map((s) => _SlotTile(slot: s)).toList(),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markComplete(
    BuildContext context,
    WidgetRef ref,
    BookingModel booking,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Mark Session Complete?'),
            content: Text(
              'Mark your session with ${booking.userName} as completed? This will allow them to rate the session.',
              style: AppTextStyles.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Not Yet'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Mark Complete'),
              ),
            ],
          ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await ref.read(bookingServiceProvider).markCompleted(booking.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session marked as completed.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _showAllBookings(BuildContext context, WidgetRef ref, String coachId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.getSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AllBookingsSheet(coachId: coachId),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final CoachModel coach;
  final List<BookingModel> bookings;

  const _StatsRow({required this.coach, required this.bookings});

  @override
  Widget build(BuildContext context) {
    final confirmed =
        bookings
            .where((b) => b.bookingStatus == BookingStatus.confirmed)
            .length;
    final completed =
        bookings
            .where((b) => b.bookingStatus == BookingStatus.completed)
            .length;
    final totalEarned = bookings
        .where((b) => b.paymentStatusEnum == PaymentStatus.paid)
        .fold<double>(0, (sum, b) => sum + b.coachRate);

    return Row(
      children: [
        _StatCard(
          label: 'Upcoming',
          value: '$confirmed',
          icon: Icons.upcoming_rounded,
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Completed',
          value: '$completed',
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Earned',
          value: _fmtMoney(totalEarned, coach.currency),
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  String _fmtMoney(double amount, String currency) {
    if (amount >= 1000000)
      return '${currency} ${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000)
      return '${currency} ${(amount / 1000).toStringAsFixed(0)}k';
    return '$currency ${amount.toStringAsFixed(0)}';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.getTextSecondary(context),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 10),
            Text(
              label,
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  const _EmptySection({
    required this.icon,
    required this.message,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: AppColors.getTextSecondary(context).withOpacity(0.3),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onAction,
              child: Text(
                action!,
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoachBookingTile extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onMarkComplete;

  const _CoachBookingTile({required this.booking, this.onMarkComplete});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, d MMM').format(booking.scheduledDateTime);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.getTextSecondary(context).withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.userName,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  booking.sessionTypeEnum.shortLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontSize: 11,
                  ),
                ),
                if (booking.notes != null && booking.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '📝 ${booking.notes!}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                date,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
              Text(
                '${booking.formattedStartTime} – ${booking.formattedEndTime}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextSecondary(context),
                  fontSize: 10,
                ),
              ),
              if (onMarkComplete != null) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onMarkComplete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Mark Complete',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final TimeSlotModel slot;

  const _SlotTile({required this.slot});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, d MMM').format(slot.dateTime);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_available_rounded,
            color: AppColors.success,
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            '$date  ·  ${slot.formattedStart}',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '${slot.durationMinutes}min',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllBookingsSheet extends ConsumerWidget {
  final String coachId;

  const _AllBookingsSheet({required this.coachId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(coachBookingsProvider(coachId));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.getTextSecondary(context).withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'All Bookings',
                style: AppTextStyles.headlineSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: bookingsAsync.when(
                loading:
                    () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                error: (err, _) => Center(child: Text('$err')),
                data:
                    (bookings) =>
                        bookings.isEmpty
                            ? const Center(child: Text('No bookings yet.'))
                            : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: bookings.length,
                              itemBuilder:
                                  (_, i) =>
                                      _CoachBookingTile(booking: bookings[i]),
                            ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NotACoachScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Coach Portal',
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 64,
                color: AppColors.getTextSecondary(context).withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'Not a Registered Coach',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your account has not been approved as a Nexus coach yet. Apply to join our team.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CoachRequirementsScreen(),
                      ),
                    ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Apply to be a Coach'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
