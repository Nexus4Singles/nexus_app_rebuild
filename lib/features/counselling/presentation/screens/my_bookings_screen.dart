import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../application/booking_service.dart';
import '../../application/counselling_providers.dart';
import '../../domain/counselling_models.dart';
import '../widgets/booking_card.dart';
import 'booking_confirmation_screen.dart';
import 'rate_session_screen.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(myBookingsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
            'My Bookings',
            style: AppTextStyles.headlineSmall
                .copyWith(fontWeight: FontWeight.w700),
          ),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.getTextSecondary(context),
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: bookingsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (bookings) {
            // Auto-cancel any pending-payment bookings whose 3-hour window expired
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(bookingServiceProvider).expireStaleBookings(bookings);
            });

            final now = DateTime.now();
            final upcoming = bookings
                .where((b) =>
                    b.scheduledDateTime.isAfter(now) &&
                    b.bookingStatus != BookingStatus.cancelled &&
                    b.bookingStatus != BookingStatus.completed)
                .toList();
            final past = bookings
                .where((b) =>
                    b.scheduledDateTime.isBefore(now) ||
                    b.bookingStatus == BookingStatus.cancelled ||
                    b.bookingStatus == BookingStatus.completed)
                .toList();

            return TabBarView(
              children: [
                _BookingList(
                  bookings: upcoming,
                  emptyMessage: 'No upcoming sessions',
                  emptySubtext:
                      'Book a session with one of our counselors to get started.',
                  allowCancel: true,
                  onCancel: (b) => _cancelBooking(context, ref, b),
                  onReturnToPayment: (b) => _returnToPayment(context, b),
                ),
                _BookingList(
                  bookings: past,
                  emptyMessage: 'No past sessions yet',
                  emptySubtext: 'Your completed sessions will appear here.',
                  allowRate: true,
                  onRate: (b) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RateSessionScreen(booking: b),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _returnToPayment(BuildContext context, BookingModel booking) {
    final method = PaymentMethod.values.firstWhere(
      (m) => m.firestoreKey == booking.paymentMethod,
      orElse: () => PaymentMethod.flutterwave,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(
          booking: booking,
          paymentMethod: method,
          popOnClose: true,
        ),
      ),
    );
  }

  Future<void> _cancelBooking(
      BuildContext context, WidgetRef ref, BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel your session with ${booking.coachName}?',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Please note that cancellation and refund policies apply.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Session'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(bookingServiceProvider).cancelBooking(booking.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking cancelled successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final String emptyMessage;
  final String emptySubtext;
  final bool allowCancel;
  final bool allowRate;
  final void Function(BookingModel)? onCancel;
  final void Function(BookingModel)? onRate;
  final void Function(BookingModel)? onReturnToPayment;

  const _BookingList({
    required this.bookings,
    required this.emptyMessage,
    required this.emptySubtext,
    this.allowCancel = false,
    this.allowRate = false,
    this.onCancel,
    this.onRate,
    this.onReturnToPayment,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 56,
                color: AppColors.getTextSecondary(context).withOpacity(0.3),
              ),
              const SizedBox(height: 14),
              Text(
                emptyMessage,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtext,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: bookings.length,
      itemBuilder: (context, i) => BookingCard(
        booking: bookings[i],
        onCancel: allowCancel ? () => onCancel?.call(bookings[i]) : null,
        onRate: allowRate ? () => onRate?.call(bookings[i]) : null,
        onReturnToPayment: bookings[i].bookingStatus == BookingStatus.pendingPayment
            ? () => onReturnToPayment?.call(bookings[i])
            : null,
      ),
    );
  }
}
