import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../application/booking_service.dart';
import '../../application/counselling_providers.dart';
import '../../application/payment_service.dart';
import '../../domain/counselling_models.dart';
import '../../../subscription/presentation/screens/subscription_screen.dart';

class BookingConfirmationScreen extends ConsumerStatefulWidget {
  final BookingModel booking;
  final PaymentMethod paymentMethod;

  /// When true, the close/× button pops back to the previous screen instead
  /// of clearing the entire nav stack. Use this when opening from My Bookings.
  final bool popOnClose;

  const BookingConfirmationScreen({
    super.key,
    required this.booking,
    required this.paymentMethod,
    this.popOnClose = false,
  });

  @override
  ConsumerState<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState
    extends ConsumerState<BookingConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  late BookingModel _currentBooking;
  bool _isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessingPayment = true);
    try {
      // 1. Open Flutterwave in-app payment modal
      final result = await PaymentService().chargeFlutterwave(
        context: context,
        booking: _currentBooking,
      );

      // 2. Verify server-side and confirm booking in Firestore.
      // Run the verify call regardless of mounted state — it's a network call
      // that doesn't touch the widget tree. Only skip if payment failed.
      if (!result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Payment cancelled.'),
              backgroundColor: AppColors.error,
            ),
          );

          // If the user cancelled the Flutterwave flow, return them to the
          // subscriptions screen so they can retry or pick another option.
          final wasCancelled = (result.errorMessage ?? '').toLowerCase().contains('cancel');
          if (wasCancelled) {
            if (widget.popOnClose && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          }
        }
        return;
      }

      await PaymentService().verifyAndConfirmPayment(
        bookingId: _currentBooking.id,
        txRef: result.txRef!,
      );
      // Firestore stream (bookingStreamProvider) updates _currentBooking automatically.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  void _goHome() {
    if (widget.popOnClose && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    }
  }

  Future<void> _confirmClose() async {
    if (_isPaid) {
      _goHome();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Leave this booking?'),
            content: const Text(
              'Your booking has been saved. You can complete payment anytime from My Bookings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Leave'),
              ),
            ],
          ),
    );
    if (confirmed == true && mounted) _goHome();
  }

  bool get _isPaid =>
      _currentBooking.paymentStatusEnum == PaymentStatus.paid ||
      _currentBooking.bookingStatus == BookingStatus.confirmed;

  @override
  Widget build(BuildContext context) {
    // Also listen to live booking updates
    ref.listen(bookingStreamProvider(_currentBooking.id), (prev, next) {
      next.whenData((booking) {
        if (booking != null && mounted) {
          setState(() => _currentBooking = booking);
        }
      });
    });

    final sessionDate = _currentBooking.scheduledDateTime;
    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(sessionDate);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmClose();
      },
      child: Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          surfaceTintColor: AppColors.getBackground(context),
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _confirmClose,
            tooltip: 'Close',
          ),
          title: Text(
            _isPaid ? 'Booking Confirmed' : 'Booking Created',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                // ── Success illustration ──
                FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      Text(
                        _isPaid ? 'Booking Confirmed!' : 'Booking Created!',
                        style: AppTextStyles.headlineLarge.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isPaid
                            ? 'Your session is confirmed. Check your email for details.'
                            : 'Complete payment to confirm your session.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.getTextSecondary(context),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Payment status banner ──
                if (!_isPaid)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tap "Complete Payment" below to secure your booking.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_isPaid)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppColors.success,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Payment confirmed! Confirmation emails sent to both you and ${_currentBooking.coachName}.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // ── Session summary card ──
                _SummaryCard(
                  booking: _currentBooking,
                  formattedDate: formattedDate,
                ),

                const SizedBox(height: 20),

                // ── Meeting link card ──
                _MeetingLinkCard(meetingLink: _currentBooking.meetingLink),

                const SizedBox(height: 28),

                // ── Actions ──
                if (!_isPaid) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessingPayment ? null : _processPayment,
                      icon:
                          _isProcessingPayment
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.payment_rounded, size: 18),
                      label: Text(
                        _isProcessingPayment
                            ? 'Processing…'
                            : 'Complete Payment via ${widget.paymentMethod.label}',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _goHome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        widget.popOnClose
                            ? 'Back to My Bookings'
                            : 'Back to Home',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed:
                        () =>
                            widget.popOnClose
                                ? _goHome()
                                : Navigator.of(
                                  context,
                                ).pushNamed('/my-bookings'),
                    child: Text(
                      'View My Bookings',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final BookingModel booking;
  final String formattedDate;

  const _SummaryCard({required this.booking, required this.formattedDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _Row(
            icon: Icons.person_outline_rounded,
            label: 'Counselor',
            value: booking.coachName,
          ),
          const _Divider(),
          _Row(
            icon: booking.sessionTypeEnum.icon,
            label: 'Session',
            value: booking.sessionTypeEnum.label,
          ),
          const _Divider(),
          _Row(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: formattedDate,
          ),
          const _Divider(),
          _Row(
            icon: Icons.schedule_rounded,
            label: 'Time',
            value:
                '${booking.formattedStartTime} – ${booking.formattedEndTime} (${booking.timezoneLabel})',
          ),
          const _Divider(),
          _Row(
            icon: Icons.payments_outlined,
            label: 'Amount',
            value:
                '${booking.currency} ${NumberFormat('#,###').format(booking.totalAmount)}',
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.getTextSecondary(context)),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: AppColors.getTextSecondary(context).withOpacity(0.1),
    );
  }
}

class _MeetingLinkCard extends StatelessWidget {
  final String meetingLink;

  const _MeetingLinkCard({required this.meetingLink});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.primary.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.videocam_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Meeting Room',
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'Powered by Jitsi Meet (free)',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.getBackground(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    meetingLink,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: meetingLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Meeting link copied!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This link will also be included in the confirmation email sent to both you and your counselor.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
