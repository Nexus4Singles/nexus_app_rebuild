import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/providers/user_provider.dart';
import '../../application/booking_service.dart';
import '../../domain/counselling_models.dart';
import 'booking_confirmation_screen.dart';

class BookingSummaryScreen extends ConsumerStatefulWidget {
  final CoachModel coach;
  final SessionType sessionType;
  final TimeSlotModel slot;

  const BookingSummaryScreen({
    super.key,
    required this.coach,
    required this.sessionType,
    required this.slot,
  });

  @override
  ConsumerState<BookingSummaryScreen> createState() =>
      _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends ConsumerState<BookingSummaryScreen> {
  PaymentMethod _paymentMethod = PaymentMethod.flutterwave;
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _rate =>
      widget.coach.rateForSession(widget.sessionType.firestoreKey);
  double get _commission => double.parse((_rate * 0.04).toStringAsFixed(2));

  String _formatAmount(double amount) {
    final formatted = NumberFormat('#,###', 'en_US').format(amount);
    return '${widget.coach.currency} $formatted';
  }

  Future<void> _handleConfirm() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (user == null || firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to book a session.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bookingService = ref.read(bookingServiceProvider);
      final booking = await bookingService.createBooking(
        userId: firebaseUser.uid,
        coachId: widget.coach.id,
        slot: widget.slot,
        coach: widget.coach,
        sessionType: widget.sessionType,
        paymentMethod: _paymentMethod,
        userName: user.name ?? firebaseUser.displayName ?? 'User',
        userEmail: user.email ?? firebaseUser.email ?? '',
        notes:
            _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => BookingConfirmationScreen(
                booking: booking,
                paymentMethod: _paymentMethod,
              ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionDate = widget.slot.dateTime;
    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(sessionDate);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Booking Summary',
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Session Info Card ──
            _SectionCard(
              child: Column(
                children: [
                  _BookingRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Counselor',
                    value: widget.coach.name,
                    valueStyle: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _Divider(),
                  _BookingRow(
                    icon: widget.sessionType.icon,
                    label: 'Session Type',
                    value: widget.sessionType.label,
                  ),
                  _Divider(),
                  _BookingRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date',
                    value: formattedDate,
                  ),
                  _Divider(),
                  _BookingRow(
                    icon: Icons.schedule_rounded,
                    label: 'Time',
                    value:
                        '${widget.slot.formattedStart} – ${widget.slot.formattedEnd} (${widget.coach.timezoneLabel})',
                  ),
                  _Divider(),
                  _BookingRow(
                    icon: Icons.timelapse_rounded,
                    label: 'Duration',
                    value: '${widget.slot.durationMinutes} minutes',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Meeting link preview ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.videocam_outlined,
                    color: AppColors.info,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your Jitsi Meet link will be emailed to you and your counselor after payment.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.info,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Notes ──
            Text(
              'Notes for your counselor (optional)',
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              maxLength: 300,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText:
                    'Brief intro, what you\'d like to discuss, any specific concerns...',
                hintStyle: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                filled: true,
                fillColor: AppColors.getSurface(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.getTextSecondary(context).withOpacity(0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.getTextSecondary(context).withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                counterStyle: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextSecondary(context),
                  fontSize: 10,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Price Breakdown ──
            Text(
              'Price Breakdown',
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _SectionCard(
              child: Column(
                children: [
                  _PriceRow(
                    label: '${widget.sessionType.shortLabel} session (1 hr)',
                    amount: _formatAmount(_rate),
                  ),
                  _Divider(),
                  _PriceRow(
                    label: 'Platform fee (4%)',
                    amount: _formatAmount(_commission),
                    isSubtle: true,
                  ),
                  _Divider(),
                  _PriceRow(
                    label: 'Total',
                    amount: _formatAmount(_rate + _commission),
                    isBold: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Payment Method ──
            Text(
              'Payment Method',
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ...PaymentMethod.values
                .where((m) => m == PaymentMethod.flutterwave)
                .map(
                  (method) => _PaymentMethodTile(
                    method: method,
                    isSelected: _paymentMethod == method,
                    onTap: () => setState(() => _paymentMethod = method),
                  ),
                ),

            const SizedBox(height: 8),
            Text(
              'Payment is processed securely in-app via ${_paymentMethod.label}.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.getTextSecondary(context),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),

      // ── Sticky CTA ──
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                      : Text(
                        'Confirm & Proceed to Payment',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: AppColors.getTextSecondary(context).withOpacity(0.1),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _BookingRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.getTextSecondary(context)),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const Spacer(),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style:
                  valueStyle ??
                  AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String amount;
  final bool isBold;
  final bool isSubtle;

  const _PriceRow({
    required this.label,
    required this.amount,
    this.isBold = false,
    this.isSubtle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
              color: isSubtle ? AppColors.getTextSecondary(context) : null,
              fontSize: isSubtle ? 12 : 14,
            ),
          ),
          Text(
            amount,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color:
                  isBold
                      ? AppColors.primary
                      : isSubtle
                      ? AppColors.getTextSecondary(context)
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final PaymentMethod method;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary.withOpacity(0.06)
                  : AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.primary
                    : AppColors.getTextSecondary(context).withOpacity(0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              method.icon,
              size: 22,
              color:
                  isSelected
                      ? AppColors.primary
                      : AppColors.getTextSecondary(context),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method.label,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.primary : null,
                  ),
                ),
                Text(
                  method.subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSelected
                          ? AppColors.primary
                          : AppColors.getTextSecondary(
                            context,
                          ).withOpacity(0.3),
                  width: 2,
                ),
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
              child:
                  isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}
