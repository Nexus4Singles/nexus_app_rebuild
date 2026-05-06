import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/counselling_models.dart';

final coachServiceProvider = Provider<CoachService>((ref) {
  return CoachService(FirebaseFirestore.instance);
});

class CoachService {
  final FirebaseFirestore _db;

  CoachService(this._db);

  CollectionReference get _coaches => _db.collection('coaches');

  // ── Public coach queries ──────────────────────────────────────────────────

  /// Watch all available coaches, optionally filtered by sessionType key.
  Stream<List<CoachModel>> watchCoaches({String? sessionTypeKey}) {
    Query query = _coaches.where('isAvailable', isEqualTo: true);
    if (sessionTypeKey != null) {
      query = query.where('sessionTypes', arrayContains: sessionTypeKey);
    }
    return query.snapshots().map(
      (snap) => snap.docs.map(CoachModel.fromFirestore).toList(),
    );
  }

  Future<CoachModel?> getCoach(String coachId) async {
    final doc = await _coaches.doc(coachId).get();
    if (!doc.exists) return null;
    return CoachModel.fromFirestore(doc);
  }

  /// Check if the current user is a coach and return their coach profile.
  Stream<CoachModel?> watchCoachByUserId(String userId) {
    return _coaches
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.isEmpty
                  ? null
                  : CoachModel.fromFirestore(snap.docs.first),
        );
  }

  // ── Slot management ───────────────────────────────────────────────────────

  CollectionReference _slots(String coachId) =>
      _coaches.doc(coachId).collection('slots');

  /// Watch all available (non-booked) slots for a coach from today onwards.
  /// Filters isBooked client-side to avoid requiring a composite Firestore index.
  Stream<List<TimeSlotModel>> watchAvailableSlots(String coachId) {
    // Use UTC midnight to match slot dates stored in UTC
    final now = DateTime.now();
    final todayUtcMidnight = DateTime.utc(
      now.toUtc().year,
      now.toUtc().month,
      now.toUtc().day,
      0,
      0,
      0,
    );
    final todayMidnight = Timestamp.fromDate(todayUtcMidnight);
    return _slots(coachId)
        .where('date', isGreaterThanOrEqualTo: todayMidnight)
        .orderBy('date')
        .snapshots()
        .map((snap) {
          final slots =
              snap.docs
                  .map(TimeSlotModel.fromFirestore)
                  .where((s) => !s.isBooked)
                  .toList();
          slots.sort((a, b) {
            final dc = a.date.compareTo(b.date);
            return dc != 0 ? dc : a.startTime.compareTo(b.startTime);
          });
          return slots;
        });
  }

  /// Watch ALL slots for a coach (booked + available) — for coach dashboard.
  Stream<List<TimeSlotModel>> watchAllSlots(String coachId) {
    // Use UTC midnight to match slot dates stored in UTC
    final now = DateTime.now();
    final todayUtcMidnight = DateTime.utc(
      now.toUtc().year,
      now.toUtc().month,
      now.toUtc().day,
      0,
      0,
      0,
    );
    final todayMidnight = Timestamp.fromDate(todayUtcMidnight);
    return _slots(coachId)
        .where('date', isGreaterThanOrEqualTo: todayMidnight)
        .orderBy('date')
        .snapshots()
        .map((snap) {
          final slots = snap.docs.map(TimeSlotModel.fromFirestore).toList();
          slots.sort((a, b) {
            final dc = a.date.compareTo(b.date);
            return dc != 0 ? dc : a.startTime.compareTo(b.startTime);
          });
          return slots;
        });
  }

  /// Add a new availability slot (by coach).
  Future<String> addSlot(String coachId, TimeSlotModel slot) async {
    final ref = await _slots(coachId).add(slot.toFirestore());
    return ref.id;
  }

  /// Remove a slot (only if it hasn't been booked).
  Future<void> removeSlot(String coachId, String slotId) async {
    final doc = await _slots(coachId).doc(slotId).get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    if (data['isBooked'] == true) {
      throw Exception('Cannot remove a slot that has an active booking.');
    }
    await _slots(coachId).doc(slotId).delete();
  }

  // ── Rating system ─────────────────────────────────────────────────────────

  /// Submit a rating for a coach after a completed session.
  Future<void> submitRating(BookingRatingModel rating) async {
    final batch = _db.batch();

    // 1. Write rating document
    final ratingRef = _db.collection('bookingRatings').doc(rating.bookingId);
    batch.set(ratingRef, rating.toFirestore());

    // 2. Update booking with userRating
    final bookingRef = _db.collection('bookings').doc(rating.bookingId);
    batch.update(bookingRef, {
      'userRating': rating.rating,
      'userReview': rating.review,
      'status': 'completed',
    });

    await batch.commit();

    // 3. Update coach aggregate rating (outside batch for transaction safety)
    await _db.runTransaction((txn) async {
      final coachDoc = await txn.get(_coaches.doc(rating.coachId));
      if (!coachDoc.exists) return;
      final data = coachDoc.data() as Map<String, dynamic>;
      final currentTotal = data['totalRatings'] as int? ?? 0;
      final currentRating = (data['rating'] as num? ?? 5.0).toDouble();

      final newTotal = currentTotal + 1;
      final newRating =
          ((currentRating * currentTotal) + rating.rating) / newTotal;

      txn.update(_coaches.doc(rating.coachId), {
        'totalRatings': newTotal,
        'rating': double.parse(newRating.toStringAsFixed(1)),
      });
    });
  }

  /// Update coach profile fields (for approved coaches managing their own profile).
  Future<void> updateCoachProfile(
    String coachId,
    Map<String, dynamic> fields,
  ) async {
    await _coaches.doc(coachId).update(fields);
  }
}
