const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();

/**
 * SCHEDULED CLOUD FUNCTION: Expire Stale Bookings
 *
 * Runs every 15 minutes. Finds all bookings that are:
 *   - status == "pending_payment"
 *   - paymentExpiresAt < now
 *
 * For each expired booking it atomically:
 *   1. Sets the booking status to "cancelled"
 *   2. Releases the coach's time slot (isBooked → false, bookingId → null)
 *
 * This ensures slot availability is restored even if the user never
 * re-opens the app, closing the gap left by the client-side expiry check.
 */
exports.expireStaleBookings = functions.pubsub
  .schedule('every 15 minutes')
  .timeZone('UTC')
  .onRun(async (_context) => {
    const now = admin.firestore.Timestamp.now();

    // Query only the bookings that are pending AND whose expiry window has passed
    const snapshot = await db
      .collection('bookings')
      .where('status', '==', 'pending_payment')
      .where('paymentExpiresAt', '<=', now)
      .get();

    if (snapshot.empty) {
      console.log('[expireStaleBookings] No expired bookings found.');
      return null;
    }

    console.log(`[expireStaleBookings] Expiring ${snapshot.size} stale booking(s)...`);

    // Firestore batches are capped at 500 writes; use multiple batches if needed
    const batches = [];
    let batch = db.batch();
    let opCount = 0;

    for (const doc of snapshot.docs) {
      const booking = doc.data();
      const { coachId, slotId } = booking;

      // 1. Cancel the booking
      batch.update(doc.ref, {
        status: 'cancelled',
        updatedAt: now,
      });
      opCount++;

      // 2. Release the slot (if we have the reference info)
      if (coachId && slotId) {
        const slotRef = db
          .collection('coaches')
          .doc(coachId)
          .collection('slots')
          .doc(slotId);

        batch.update(slotRef, {
          isBooked: false,
          bookingId: null,
        });
        opCount++;
      }

      // Flush batch every 400 writes (leave headroom below the 500-write limit)
      if (opCount >= 400) {
        batches.push(batch.commit());
        batch = db.batch();
        opCount = 0;
      }
    }

    // Commit any remaining writes
    if (opCount > 0) {
      batches.push(batch.commit());
    }

    await Promise.all(batches);

    console.log(
      `[expireStaleBookings] ✅ Cancelled ${snapshot.size} booking(s) and released their slots.`
    );
    return null;
  });
