import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_v2/core/providers/user_provider.dart';
import 'coach_service.dart';
import 'booking_service.dart';
import '../domain/counselling_models.dart';

// ── Coach providers ───────────────────────────────────────────────────────────

/// All available coaches.
final allCoachesProvider = StreamProvider<List<CoachModel>>((ref) {
  return ref.read(coachServiceProvider).watchCoaches();
});

/// Available coaches filtered to a specific session type.
final coachesBySessionTypeProvider =
    StreamProvider.family<List<CoachModel>, String>((ref, sessionTypeKey) {
  return ref.read(coachServiceProvider).watchCoaches(sessionTypeKey: sessionTypeKey);
});

/// Single coach profile.
final coachDetailProvider =
    FutureProvider.family<CoachModel?, String>((ref, coachId) {
  return ref.read(coachServiceProvider).getCoach(coachId);
});

/// Check if the current user is an approved coach.
final myCoachProfileProvider = StreamProvider<CoachModel?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.read(coachServiceProvider).watchCoachByUserId(user.id);
    },
    orElse: () => Stream.value(null),
  );
});

// ── Slot providers ────────────────────────────────────────────────────────────

/// Available (un-booked) slots for a coach from today onwards.
/// keepAlive keeps the Firestore stream alive after the first load so that
/// navigating back to the profile/calendar is instant on repeated visits.
final availableSlotsProvider =
    StreamProvider.family<List<TimeSlotModel>, String>((ref, coachId) {
  ref.keepAlive();
  return ref.read(coachServiceProvider).watchAvailableSlots(coachId);
});

/// All slots (available + booked) for a coach — used in coach dashboard.
final allCoachSlotsProvider =
    StreamProvider.family<List<TimeSlotModel>, String>((ref, coachId) {
  ref.keepAlive();
  return ref.read(coachServiceProvider).watchAllSlots(coachId);
});

/// Dates that have at least one available slot for a coach.
final availableDatesProvider =
    Provider.family<Set<DateTime>, List<TimeSlotModel>>((ref, slots) {
  return slots.map((s) {
    final d = s.dateTime;
    return DateTime(d.year, d.month, d.day);
  }).toSet();
});

// ── Booking providers ─────────────────────────────────────────────────────────

/// All bookings for the current user.
final myBookingsProvider = StreamProvider<List<BookingModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value([]);
      return ref.read(bookingServiceProvider).watchUserBookings(user.id);
    },
    orElse: () => Stream.value([]),
  );
});

/// Bookings for a specific coach.
final coachBookingsProvider =
    StreamProvider.family<List<BookingModel>, String>((ref, coachId) {
  return ref.read(bookingServiceProvider).watchCoachBookings(coachId);
});

/// Real-time stream for a single booking (used to watch payment confirmation).
final bookingStreamProvider =
    StreamProvider.family<BookingModel?, String>((ref, bookingId) {
  return ref.read(bookingServiceProvider).watchBooking(bookingId);
});
