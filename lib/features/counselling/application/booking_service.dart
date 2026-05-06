import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/counselling_models.dart';

final bookingServiceProvider = Provider<BookingService>((ref) {
  return BookingService(FirebaseFirestore.instance);
});

class BookingService {
  final FirebaseFirestore _db;

  BookingService(this._db);

  CollectionReference get _bookings => _db.collection('bookings');
  CollectionReference _slots(String coachId) =>
      _db.collection('coaches').doc(coachId).collection('slots');

  // ── Meeting link ──────────────────────────────────────────────────────────

  /// Generates a free Jitsi Meet room URL unique to this booking.
  static String generateMeetingLink(String bookingId) {
    final shortCode =
        bookingId.length >= 8
            ? bookingId.substring(0, 8).toUpperCase()
            : bookingId.toUpperCase();
    return 'https://meet.jit.si/NexusCoaching-$shortCode';
  }

  // ── Create booking ────────────────────────────────────────────────────────

  /// Creates a booking and marks the slot as reserved in a single transaction.
  Future<BookingModel> createBooking({
    required String userId,
    required String coachId,
    required TimeSlotModel slot,
    required CoachModel coach,
    required SessionType sessionType,
    required PaymentMethod paymentMethod,
    required String userName,
    required String userEmail,
    String? notes,
  }) async {
    final bookingRef = _bookings.doc();
    final meetingLink = generateMeetingLink(bookingRef.id);

    final rate = coach.rateForSession(sessionType.firestoreKey);
    final commission = double.parse((rate * 0.04).toStringAsFixed(2));

    final now = Timestamp.now();
    final paymentExpiry = Timestamp.fromDate(
      DateTime.now().add(const Duration(hours: 3)),
    );

    final booking = BookingModel(
      id: bookingRef.id,
      userId: userId,
      coachId: coachId,
      slotId: slot.id,
      sessionType: sessionType.firestoreKey,
      scheduledDate: slot.date,
      startTime: slot.startTime,
      endTime: slot.endTime,
      durationMinutes: slot.durationMinutes,
      coachName: coach.name,
      coachPhotoUrl: coach.profilePhotoUrl,
      userName: userName,
      userEmail: userEmail,
      coachEmail: coach.email,
      coachTimezone: coach.timezone,
      coachRate: rate,
      nexusCommission: commission,
      totalAmount: rate + commission,
      currency: coach.currency,
      paymentMethod: paymentMethod.firestoreKey,
      paymentStatus: PaymentStatus.pending.firestoreKey,
      status: BookingStatus.pendingPayment.firestoreKey,
      meetingLink: meetingLink,
      notes: notes,
      emailsSent: false,
      createdAt: now,
      paymentExpiresAt: paymentExpiry,
    );

    // Transaction: write booking + mark slot as booked atomically
    await _db.runTransaction((txn) async {
      final slotRef = _slots(coachId).doc(slot.id);
      final freshSlot = await txn.get(slotRef);
      if (!freshSlot.exists) throw Exception('Time slot no longer exists.');

      final slotData = freshSlot.data() as Map<String, dynamic>;
      if (slotData['isBooked'] == true) {
        throw Exception(
          'This time slot was just booked by someone else. Please pick another slot.',
        );
      }

      // Reserve the slot
      txn.update(slotRef, {'isBooked': true, 'bookingId': bookingRef.id});

      // Create the booking
      txn.set(bookingRef, booking.toFirestore());
    });

    return booking;
  }

  // ── Payment updates ───────────────────────────────────────────────────────

  Future<void> updatePaymentDetails({
    required String bookingId,
    required String paymentMethod,
    String? paymentUrl,
    String? paymentReference,
  }) async {
    await _bookings.doc(bookingId).update({
      'paymentMethod': paymentMethod,
      if (paymentUrl != null) 'paymentUrl': paymentUrl,
      if (paymentReference != null) 'paymentReference': paymentReference,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> confirmPayment(String bookingId, String reference) async {
    await _bookings.doc(bookingId).update({
      'paymentStatus': PaymentStatus.paid.firestoreKey,
      'paymentReference': reference,
      'status': BookingStatus.confirmed.firestoreKey,
      'updatedAt': Timestamp.now(),
    });
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  Stream<BookingModel?> watchBooking(String bookingId) {
    return _bookings
        .doc(bookingId)
        .snapshots()
        .map((doc) => doc.exists ? BookingModel.fromFirestore(doc) : null);
  }

  Future<BookingModel?> getBooking(String bookingId) async {
    final doc = await _bookings.doc(bookingId).get();
    if (!doc.exists) return null;
    return BookingModel.fromFirestore(doc);
  }

  /// Stream all bookings for a user, newest first.
  Stream<List<BookingModel>> watchUserBookings(String userId) {
    return _bookings
        .where('userId', isEqualTo: userId)
        .orderBy('scheduledDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(BookingModel.fromFirestore).toList());
  }

  /// Stream upcoming bookings for a coach.
  Stream<List<BookingModel>> watchCoachBookings(String coachId) {
    return _bookings
        .where('coachId', isEqualTo: coachId)
        .orderBy('scheduledDate')
        .snapshots()
        .map((snap) => snap.docs.map(BookingModel.fromFirestore).toList());
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> cancelBooking(String bookingId) async {
    final bookingDoc = await _bookings.doc(bookingId).get();
    if (!bookingDoc.exists) return;
    final booking = BookingModel.fromFirestore(bookingDoc);

    final batch = _db.batch();

    batch.update(_bookings.doc(bookingId), {
      'status': BookingStatus.cancelled.firestoreKey,
      'updatedAt': Timestamp.now(),
    });

    // Free the slot
    final slotRef = _slots(booking.coachId).doc(booking.slotId);
    batch.update(slotRef, {'isBooked': false, 'bookingId': null});

    await batch.commit();
  }

  Future<void> markCompleted(String bookingId) async {
    await _bookings.doc(bookingId).update({
      'status': BookingStatus.completed.firestoreKey,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Cancels all pending-payment bookings whose payment window has expired.
  /// Call this when the user opens their bookings screen.
  Future<void> expireStaleBookings(List<BookingModel> bookings) async {
    final expired =
        bookings
            .where(
              (b) =>
                  b.bookingStatus == BookingStatus.pendingPayment &&
                  b.isPaymentExpired,
            )
            .toList();
    if (expired.isEmpty) return;

    final batch = _db.batch();
    for (final booking in expired) {
      // Update booking status
      batch.update(_bookings.doc(booking.id), {
        'status': BookingStatus.cancelled.firestoreKey,
        'updatedAt': Timestamp.now(),
      });
      // Release the slot
      batch.update(_slots(booking.coachId).doc(booking.slotId), {
        'isBooked': false,
        'bookingId': null,
      });
    }
    await batch.commit();
  }
}
