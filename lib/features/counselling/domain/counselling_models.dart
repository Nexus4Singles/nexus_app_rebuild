import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ============================================================================
// ENUMS
// ============================================================================

enum SessionType {
  individual,
  premarital,
  postMarital,
  parenting;

  String get label => switch (this) {
    individual => 'Individual Counseling',
    premarital => 'Premarital Counseling',
    postMarital => 'Post-Marital Counseling',
    parenting => 'Parenting Counseling',
  };

  String get shortLabel => switch (this) {
    individual => 'Individual',
    premarital => 'Premarital',
    postMarital => 'Post-Marital',
    parenting => 'Parenting',
  };

  String get description => switch (this) {
    individual =>
      'One-on-one sessions to address personal relationship challenges',
    premarital =>
      'Prepare for a strong and healthy marriage before your wedding',
    postMarital => 'Strengthen your marriage and overcome challenges together',
    parenting =>
      'Navigate parenting challenges and build a healthy family dynamic',
  };

  IconData get icon => switch (this) {
    individual => Icons.person_outline_rounded,
    premarital => Icons.favorite_border_rounded,
    postMarital => Icons.home_outlined,
    parenting => Icons.family_restroom_rounded,
  };

  String get firestoreKey => switch (this) {
    individual => 'Individual',
    premarital => 'Premarital',
    postMarital => 'PostMarital',
    parenting => 'Parenting',
  };

  static SessionType fromString(String? value) => switch (value) {
    'Individual' => individual,
    'Premarital' => premarital,
    'PostMarital' => postMarital,
    'Parenting' => parenting,
    _ => individual,
  };
}

enum BookingStatus {
  pendingPayment,
  confirmed,
  completed,
  cancelled,
  rescheduled;

  String get label => switch (this) {
    pendingPayment => 'Pending Payment',
    confirmed => 'Confirmed',
    completed => 'Completed',
    cancelled => 'Cancelled',
    rescheduled => 'Rescheduled',
  };

  Color get color => switch (this) {
    pendingPayment => const Color(0xFFF97316),
    confirmed => const Color(0xFF22C55E),
    completed => const Color(0xFF3B82F6),
    cancelled => const Color(0xFFEF4444),
    rescheduled => const Color(0xFF8B5CF6),
  };

  Color get backgroundColor => switch (this) {
    pendingPayment => const Color(0xFFFFF7ED),
    confirmed => const Color(0xFFDCFCE7),
    completed => const Color(0xFFDBEAFE),
    cancelled => const Color(0xFFFEE2E2),
    rescheduled => const Color(0xFFF3E8FF),
  };

  String get firestoreKey => switch (this) {
    pendingPayment => 'pending_payment',
    confirmed => 'confirmed',
    completed => 'completed',
    cancelled => 'cancelled',
    rescheduled => 'rescheduled',
  };

  static BookingStatus fromString(String? value) => switch (value) {
    'confirmed' => confirmed,
    'completed' => completed,
    'cancelled' => cancelled,
    'rescheduled' => rescheduled,
    _ => pendingPayment,
  };
}

enum PaymentMethod {
  flutterwave,
  paypal;

  String get label => switch (this) {
    flutterwave => 'Flutterwave',
    paypal => 'PayPal',
  };

  String get subtitle => switch (this) {
    flutterwave => 'Card, Bank Transfer, USSD, Mobile Money',
    paypal => 'International Cards & PayPal Balance',
  };

  IconData get icon => switch (this) {
    flutterwave => Icons.account_balance_wallet_outlined,
    paypal => Icons.language_rounded,
  };

  String get firestoreKey => name;

  static PaymentMethod fromString(String? value) => switch (value) {
    'paypal' => paypal,
    _ => flutterwave,
  };
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded;

  String get firestoreKey => name;

  static PaymentStatus fromString(String? value) => switch (value) {
    'paid' => paid,
    'failed' => failed,
    'refunded' => refunded,
    _ => pending,
  };
}

// ============================================================================
// COACH MODEL
// ============================================================================

class CoachModel {
  final String id;
  final String userId;
  final String name;
  final String title;
  final String bio;
  final String? profilePhotoUrl;
  final List<String> sessionTypes;
  final List<String> specializations;

  /// Rates in the coach's set currency. Key is sessionType firestoreKey.
  final Map<String, double> sessionRates;
  final String currency; // 'NGN', 'USD', 'GBP', etc.
  final double rating;
  final int totalRatings;
  final int totalSessions;
  final String timezone; // e.g. 'Africa/Lagos'
  final bool isAvailable;
  final Timestamp approvedAt;
  final int yearsOfExperience;
  final String email;
  final String? linkedinProfile;
  final String? instagramHandle;
  final String? phoneNumber;

  const CoachModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.title,
    required this.bio,
    this.profilePhotoUrl,
    required this.sessionTypes,
    required this.specializations,
    required this.sessionRates,
    required this.currency,
    required this.rating,
    required this.totalRatings,
    required this.totalSessions,
    required this.timezone,
    required this.isAvailable,
    required this.approvedAt,
    required this.yearsOfExperience,
    required this.email,
    this.linkedinProfile,
    this.instagramHandle,
    this.phoneNumber,
  });

  factory CoachModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CoachModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      title: data['title'] as String? ?? 'Marriage Counselor',
      bio: data['bio'] as String? ?? '',
      profilePhotoUrl: data['profilePhotoUrl'] as String?,
      sessionTypes: List<String>.from(data['sessionTypes'] as List? ?? []),
      specializations: List<String>.from(
        data['specializations'] as List? ?? [],
      ),
      sessionRates: Map<String, double>.from(
        (data['sessionRates'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      ),
      currency: data['currency'] as String? ?? 'NGN',
      rating: (data['rating'] as num? ?? 5.0).toDouble(),
      totalRatings: data['totalRatings'] as int? ?? 0,
      totalSessions: data['totalSessions'] as int? ?? 0,
      timezone: data['timezone'] as String? ?? 'Africa/Lagos',
      isAvailable: data['isAvailable'] as bool? ?? true,
      approvedAt: data['approvedAt'] as Timestamp? ?? Timestamp.now(),
      yearsOfExperience: data['yearsOfExperience'] as int? ?? 0,
      email: data['email'] as String? ?? '',
      linkedinProfile: data['linkedinProfile'] as String?,
      instagramHandle: data['instagramHandle'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'name': name,
    'title': title,
    'bio': bio,
    'profilePhotoUrl': profilePhotoUrl,
    'sessionTypes': sessionTypes,
    'specializations': specializations,
    'sessionRates': sessionRates,
    'currency': currency,
    'rating': rating,
    'totalRatings': totalRatings,
    'totalSessions': totalSessions,
    'timezone': timezone,
    'isAvailable': isAvailable,
    'approvedAt': approvedAt,
    'yearsOfExperience': yearsOfExperience,
    'email': email,
    'linkedinProfile': linkedinProfile,
    'instagramHandle': instagramHandle,
    'phoneNumber': phoneNumber,
  };

  double rateForSession(String sessionTypeKey) =>
      sessionRates[sessionTypeKey] ?? sessionRates.values.firstOrNull ?? 0.0;

  String get formattedRating =>
      totalRatings == 0 ? 'New' : rating.toStringAsFixed(1);

  String get ratingSubtext =>
      totalRatings == 0
          ? ''
          : '($totalRatings review${totalRatings == 1 ? '' : 's'})';

  /// Short timezone abbreviation derived from the coach's IANA timezone, e.g. "WAT".
  String get timezoneLabel => _tzLabel(timezone);
}

// ============================================================================
// TIME SLOT MODEL
// ============================================================================

class TimeSlotModel {
  final String id;
  final String coachId;
  final Timestamp date;
  final String startTime; // "10:00" (24-hour)
  final String endTime; // "11:00"
  final int durationMinutes;
  final bool isBooked;
  final String? bookingId;
  final List<String> sessionTypes; // which session types this slot supports

  const TimeSlotModel({
    required this.id,
    required this.coachId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.isBooked,
    this.bookingId,
    required this.sessionTypes,
  });

  DateTime get dateTime => date.toDate();

  /// Formatted display label, e.g. "10:00 AM"
  String get formattedStart {
    final parts = startTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? parts[1] : '00';
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  String get formattedEnd {
    final parts = endTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? parts[1] : '00';
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  bool supportsSessionType(String sessionTypeKey) =>
      sessionTypes.isEmpty || sessionTypes.contains(sessionTypeKey);

  factory TimeSlotModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TimeSlotModel(
      id: doc.id,
      coachId: data['coachId'] as String? ?? '',
      date: data['date'] as Timestamp? ?? Timestamp.now(),
      startTime: data['startTime'] as String? ?? '10:00',
      endTime: data['endTime'] as String? ?? '11:00',
      durationMinutes: data['durationMinutes'] as int? ?? 60,
      isBooked: data['isBooked'] as bool? ?? false,
      bookingId: data['bookingId'] as String?,
      sessionTypes: List<String>.from(data['sessionTypes'] as List? ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'coachId': coachId,
    'date': date,
    'startTime': startTime,
    'endTime': endTime,
    'durationMinutes': durationMinutes,
    'isBooked': isBooked,
    'bookingId': bookingId,
    'sessionTypes': sessionTypes,
  };

  TimeSlotModel copyWith({bool? isBooked, String? bookingId}) => TimeSlotModel(
    id: id,
    coachId: coachId,
    date: date,
    startTime: startTime,
    endTime: endTime,
    durationMinutes: durationMinutes,
    isBooked: isBooked ?? this.isBooked,
    bookingId: bookingId ?? this.bookingId,
    sessionTypes: sessionTypes,
  );
}

// ============================================================================
// BOOKING MODEL
// ============================================================================

/// Converts a 24-hour time string (e.g. "14:30") → "2:30 PM".
String _fmtTime(String t24) {
  final parts = t24.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? parts[1] : '00';
  final period = hour >= 12 ? 'PM' : 'AM';
  final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$h:$minute $period';
}

/// Returns a short timezone label for a given IANA timezone string.
String _tzLabel(String iana) {
  const map = {
    'Africa/Lagos': 'WAT',
    'Africa/Nairobi': 'EAT',
    'Africa/Accra': 'GMT',
    'America/New_York': 'ET',
    'America/Chicago': 'CT',
    'America/Los_Angeles': 'PT',
    'Europe/London': 'GMT',
    'Europe/Paris': 'CET',
    'Asia/Kolkata': 'IST',
    'Asia/Dubai': 'GST',
    'Australia/Sydney': 'AEDT',
  };
  return map[iana] ?? iana;
}

class BookingModel {
  final String id;
  final String userId;
  final String coachId;
  final String slotId;
  final String sessionType;
  final Timestamp scheduledDate;
  final String startTime;
  final String endTime;
  final int durationMinutes;

  // Denormalized for display & emails
  final String coachName;
  final String? coachPhotoUrl;
  final String userName;
  final String userEmail;
  final String coachEmail;
  final String coachTimezone; // IANA timezone, e.g. 'Africa/Lagos'

  // Payment
  final double coachRate;
  final double
  nexusCommission; // 4% of coachRate — charged on top, paid by user
  final double
  totalAmount; // = coachRate + nexusCommission (what the user pays)
  final String currency;
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentReference;
  final String? paymentUrl;

  // Booking lifecycle
  final String status;
  final String meetingLink; // Jitsi Meet URL
  final String? notes; // user's pre-session notes
  final bool emailsSent;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final Timestamp?
  paymentExpiresAt; // 3 hours after creation for pendingPayment

  // Post-session
  final int? userRating;
  final String? userReview;

  const BookingModel({
    required this.id,
    required this.userId,
    required this.coachId,
    required this.slotId,
    required this.sessionType,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.coachName,
    this.coachPhotoUrl,
    required this.userName,
    required this.userEmail,
    required this.coachEmail,
    required this.coachTimezone,
    required this.coachRate,
    required this.nexusCommission,
    required this.totalAmount,
    required this.currency,
    required this.paymentMethod,
    required this.paymentStatus,
    this.paymentReference,
    this.paymentUrl,
    required this.status,
    required this.meetingLink,
    this.notes,
    required this.emailsSent,
    required this.createdAt,
    this.updatedAt,
    this.paymentExpiresAt,
    this.userRating,
    this.userReview,
  });

  BookingStatus get bookingStatus => BookingStatus.fromString(status);
  PaymentStatus get paymentStatusEnum =>
      PaymentStatus.fromString(paymentStatus);
  SessionType get sessionTypeEnum => SessionType.fromString(sessionType);

  DateTime get scheduledDateTime => scheduledDate.toDate();

  /// Formats startTime/endTime as 12-hour AM/PM, e.g. "4:00 PM".
  String get formattedStartTime => _fmtTime(startTime);
  String get formattedEndTime => _fmtTime(endTime);

  /// Short timezone abbreviation, e.g. "WAT".
  String get timezoneLabel => _tzLabel(coachTimezone);

  bool get isPast => scheduledDate.toDate().isBefore(DateTime.now());
  bool get canRate =>
      bookingStatus == BookingStatus.completed && userRating == null;

  /// True if this is a pending-payment booking whose 3-hour payment window has closed.
  bool get isPaymentExpired {
    if (bookingStatus != BookingStatus.pendingPayment) return false;
    final expiry = paymentExpiresAt?.toDate();
    if (expiry == null) {
      // Legacy bookings without expiry field: expire 3h after creation
      return createdAt
          .toDate()
          .add(const Duration(hours: 3))
          .isBefore(DateTime.now());
    }
    return expiry.isBefore(DateTime.now());
  }

  /// Remaining time before payment window closes (null if not pending or already expired).
  Duration? get paymentTimeRemaining {
    if (bookingStatus != BookingStatus.pendingPayment) return null;
    final expiry =
        paymentExpiresAt?.toDate() ??
        createdAt.toDate().add(const Duration(hours: 3));
    final remaining = expiry.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      coachId: data['coachId'] as String? ?? '',
      slotId: data['slotId'] as String? ?? '',
      sessionType: data['sessionType'] as String? ?? 'Individual',
      scheduledDate: data['scheduledDate'] as Timestamp? ?? Timestamp.now(),
      startTime: data['startTime'] as String? ?? '',
      endTime: data['endTime'] as String? ?? '',
      durationMinutes: data['durationMinutes'] as int? ?? 60,
      coachName: data['coachName'] as String? ?? '',
      coachPhotoUrl: data['coachPhotoUrl'] as String?,
      userName: data['userName'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      coachEmail: data['coachEmail'] as String? ?? '',
      coachTimezone: data['coachTimezone'] as String? ?? 'Africa/Lagos',
      coachRate: (data['coachRate'] as num? ?? 0).toDouble(),
      nexusCommission: (data['nexusCommission'] as num? ?? 0).toDouble(),
      totalAmount: (data['totalAmount'] as num? ?? 0).toDouble(),
      currency: data['currency'] as String? ?? 'NGN',
      paymentMethod: data['paymentMethod'] as String? ?? 'flutterwave',
      paymentStatus: data['paymentStatus'] as String? ?? 'pending',
      paymentReference: data['paymentReference'] as String?,
      paymentUrl: data['paymentUrl'] as String?,
      status: data['status'] as String? ?? 'pending_payment',
      meetingLink: data['meetingLink'] as String? ?? '',
      notes: data['notes'] as String?,
      emailsSent: data['emailsSent'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
      paymentExpiresAt: data['paymentExpiresAt'] as Timestamp?,
      userRating: data['userRating'] as int?,
      userReview: data['userReview'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'coachId': coachId,
    'slotId': slotId,
    'sessionType': sessionType,
    'scheduledDate': scheduledDate,
    'startTime': startTime,
    'endTime': endTime,
    'durationMinutes': durationMinutes,
    'coachName': coachName,
    'coachPhotoUrl': coachPhotoUrl,
    'userName': userName,
    'userEmail': userEmail,
    'coachEmail': coachEmail,
    'coachTimezone': coachTimezone,
    'coachRate': coachRate,
    'nexusCommission': nexusCommission,
    'totalAmount': totalAmount,
    'currency': currency,
    'paymentMethod': paymentMethod,
    'paymentStatus': paymentStatus,
    'paymentReference': paymentReference,
    'paymentUrl': paymentUrl,
    'status': status,
    'meetingLink': meetingLink,
    'notes': notes,
    'emailsSent': emailsSent,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    if (paymentExpiresAt != null) 'paymentExpiresAt': paymentExpiresAt,
    'userRating': userRating,
    'userReview': userReview,
  };
}

// ============================================================================
// BOOKING RATING MODEL
// ============================================================================

class BookingRatingModel {
  final String id;
  final String bookingId;
  final String coachId;
  final String userId;
  final int rating;
  final String? review;
  final Timestamp createdAt;

  const BookingRatingModel({
    required this.id,
    required this.bookingId,
    required this.coachId,
    required this.userId,
    required this.rating,
    this.review,
    required this.createdAt,
  });

  factory BookingRatingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingRatingModel(
      id: doc.id,
      bookingId: data['bookingId'] as String? ?? '',
      coachId: data['coachId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      rating: data['rating'] as int? ?? 5,
      review: data['review'] as String?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'bookingId': bookingId,
    'coachId': coachId,
    'userId': userId,
    'rating': rating,
    'review': review,
    'createdAt': createdAt,
  };
}

// ============================================================================
// SLOT AVAILABILITY SUMMARY (Used by the calendar to highlight dates)
// ============================================================================

class SlotAvailabilitySummary {
  final DateTime date;
  final int availableCount;

  const SlotAvailabilitySummary({
    required this.date,
    required this.availableCount,
  });

  bool get hasSlots => availableCount > 0;
}
