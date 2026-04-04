import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/counselling_models.dart';

class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onTap;
  final VoidCallback? onRate;
  final VoidCallback? onCancel;
  final VoidCallback? onReturnToPayment;

  const BookingCard({
    super.key,
    required this.booking,
    this.onTap,
    this.onRate,
    this.onCancel,
    this.onReturnToPayment,
  });

  @override
  Widget build(BuildContext context) {
    final status = booking.bookingStatus;
    final sessionDate = booking.scheduledDateTime;
    final formattedDate = DateFormat('EEE, d MMM yyyy').format(sessionDate);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.getTextSecondary(context).withOpacity(0.1),
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Coach photo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: booking.coachPhotoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: booking.coachPhotoUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _CoachInitials(name: booking.coachName),
                            )
                          : _CoachInitials(name: booking.coachName),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.coachName,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          booking.sessionTypeEnum.label,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: status.backgroundColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.label,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: status.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Divider(
              height: 1,
              color: AppColors.getTextSecondary(context).withOpacity(0.1),
            ),

            // Date/time row
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _InfoChip(
                    icon: Icons.calendar_today_rounded,
                    label: formattedDate,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.schedule_rounded,
                    label:
                        '${booking.formattedStartTime} – ${booking.formattedEndTime} (${booking.timezoneLabel})',
                  ),
                ],
              ),
            ),

            // Pending payment banner with countdown
            if (status == BookingStatus.pendingPayment &&
                onReturnToPayment != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: _PaymentExpiryBanner(
                  booking: booking,
                  onPayNow: onReturnToPayment,
                ),
              ),

            // Action buttons
            if (onRate != null || onCancel != null ||
                (onReturnToPayment != null &&
                    status == BookingStatus.pendingPayment))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Row(
                  children: [
                    if (onCancel != null &&
                        (status == BookingStatus.confirmed ||
                            status == BookingStatus.pendingPayment)) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onCancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (onRate != null && booking.canRate)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onRate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Rate Session',
                              style: TextStyle(fontSize: 13)),
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
}

class _CoachInitials extends StatelessWidget {
  final String name;
  const _CoachInitials({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ').take(2).map((w) {
      return w.isNotEmpty ? w[0].toUpperCase() : '';
    }).join();

    return Container(
      color: AppColors.primaryMuted,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.getTextSecondary(context)),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.getTextSecondary(context),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// A banner shown for pending-payment bookings that shows a live countdown
/// and a "Pay Now" button. Updates every minute.
class _PaymentExpiryBanner extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback? onPayNow;

  const _PaymentExpiryBanner({required this.booking, this.onPayNow});

  @override
  State<_PaymentExpiryBanner> createState() => _PaymentExpiryBannerState();
}

class _PaymentExpiryBannerState extends State<_PaymentExpiryBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Refresh every minute so the countdown stays accurate
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatRemaining(Duration d) {
    if (d == Duration.zero) return 'Expired';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m remaining';
    return '${m}m remaining';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.booking.paymentTimeRemaining ?? Duration.zero;
    final isExpired = remaining == Duration.zero;
    final color = isExpired ? AppColors.error : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isExpired ? Icons.timer_off_rounded : Icons.timer_outlined,
            color: color,
            size: 15,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired
                      ? 'Payment window closed — slot will be released.'
                      : 'Complete payment to confirm your slot.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: color,
                    fontSize: 11,
                  ),
                ),
                Text(
                  _formatRemaining(remaining),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (!isExpired && widget.onPayNow != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onPayNow,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Pay Now',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
