import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:nexus_app_v2/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_v2/core/bootstrap/firestore_instance_provider.dart';

/// Model for coach application in review queue
class CoachApplicationReviewItem {
  final String applicationId;
  final String fullName;
  final String email;
  final String gender;
  final int yearsOfExperience;
  final String? profilePhotoUrl;
  final DateTime submittedAt;
  final String status; // pending, approved, rejected

  const CoachApplicationReviewItem({
    required this.applicationId,
    required this.fullName,
    required this.email,
    required this.gender,
    required this.yearsOfExperience,
    required this.submittedAt,
    required this.status,
    this.profilePhotoUrl,
  });

  factory CoachApplicationReviewItem.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    return CoachApplicationReviewItem(
      applicationId: data['applicationId'] ?? docId,
      fullName: data['fullName'] ?? 'Unknown',
      email: data['email'] ?? '',
      gender: data['gender'] ?? 'Not specified',
      yearsOfExperience: (data['yearsOfExperience'] as num?)?.toInt() ?? 0,
      profilePhotoUrl:
          (data['profilePhoto'] is Map)
              ? (data['profilePhoto'] as Map)['url'] as String?
              : null,
      submittedAt: _asDate(data['submittedAt']) ?? DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }
}

/// Model for full coach application details
class CoachApplicationDetail {
  final String applicationId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String gender;
  final String nationality;
  final String residenceLocation;
  final String title;
  final int yearsOfExperience;
  final String maritalStatus;
  final String credentials;
  final List<String> specializations;
  final String coachingPhilosophy;
  final String? instagramHandle;
  final String? linkedinProfile;
  final String? profilePhotoUrl;
  final String? credentialsPdfUrl;
  final DateTime submittedAt;
  final DateTime? emailSentAt;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  const CoachApplicationDetail({
    required this.applicationId,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.gender,
    required this.nationality,
    required this.residenceLocation,
    required this.title,
    required this.yearsOfExperience,
    required this.maritalStatus,
    required this.credentials,
    required this.specializations,
    required this.coachingPhilosophy,
    required this.submittedAt,
    required this.status,
    this.instagramHandle,
    this.linkedinProfile,
    this.profilePhotoUrl,
    this.credentialsPdfUrl,
    this.emailSentAt,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory CoachApplicationDetail.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    final profilePhoto =
        (data['profilePhoto'] is Map) ? data['profilePhoto'] as Map : null;
    final credentialsPdf =
        (data['credentialsPdf'] is Map) ? data['credentialsPdf'] as Map : null;

    final profilePhotoUrl = profilePhoto?['url'] as String?;
    final credentialsPdfUrl = credentialsPdf?['url'] as String?;

    // Debug logging for credentials PDF
    print('[CoachApplicationDetail] Firestore data keys: ${data.keys.join(', ')}');
    print('[CoachApplicationDetail] credentialsPdf field: ${data['credentialsPdf']}');
    print('[CoachApplicationDetail] credentialsPdf type: ${data['credentialsPdf'].runtimeType}');
    print('[CoachApplicationDetail] credentialsPdf URL extracted: $credentialsPdfUrl');
    if (credentialsPdfUrl == null || credentialsPdfUrl.isEmpty) {
      print('[⚠️ WARNING] No credentials PDF URL found! credentialsPdf=$credentialsPdf');
    } else {
      print('[✅ OK] Credentials PDF URL: $credentialsPdfUrl');
    }

    return CoachApplicationDetail(
      applicationId: data['applicationId'] ?? docId,
      fullName: data['fullName'] ?? 'Unknown',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      gender: data['gender'] ?? 'Not specified',
      nationality: data['nationality'] ?? '',
      residenceLocation: data['residenceLocation'] ?? '',
      title: data['title'] ?? '',
      yearsOfExperience: (data['yearsOfExperience'] as num?)?.toInt() ?? 0,
      maritalStatus: data['maritalStatus'] ?? '',
      credentials: data['credentials'] ?? '',
      specializations:
          (data['specializations'] is List)
              ? List<String>.from(data['specializations'])
              : [],
      coachingPhilosophy: data['coachingPhilosophy'] ?? '',
      instagramHandle: data['instagramHandle'] as String?,
      linkedinProfile: data['linkedinProfile'] as String?,
      profilePhotoUrl: profilePhotoUrl,
      credentialsPdfUrl: credentialsPdfUrl,
      submittedAt: _asDate(data['submittedAt']) ?? DateTime.now(),
      emailSentAt: _asDate(data['emailSentAt']),
      status: data['status'] ?? 'pending',
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: _asDate(data['reviewedAt']),
    );
  }
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  try {
    final toDate = v.toDate;
    if (toDate is Function) return toDate() as DateTime;
  } catch (_) {}
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// Stream of pending coach applications
final pendingCoachApplicationsProvider = StreamProvider<
  List<CoachApplicationReviewItem>
>((ref) {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  if (!firebaseReady) return Stream.value(const []);

  final fs = ref.watch(firestoreInstanceProvider);
  if (fs == null) return Stream.value(const []);

  // Real-time stream of pending coach applications
  // Note: We remove orderBy to avoid needing a composite index, and sort in code instead
  final stream =
      fs
          .collection('coachApplications')
          .where('status', isEqualTo: 'pending')
          .limit(200)
          .snapshots();

  return stream.map((snapshot) {
    final items =
        snapshot.docs
            .map(
              (d) => CoachApplicationReviewItem.fromFirestore(d.id, d.data()),
            )
            .toList();

    // Sort by submittedAt descending (newest first)
    items.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return items;
  });
});

/// Get full details for a coach application
final coachApplicationDetailProvider = FutureProvider.family<
  CoachApplicationDetail,
  String
>((ref, applicationId) async {
  final fs = ref.watch(firestoreInstanceProvider);
  if (fs == null) {
    throw Exception('Firestore not initialized');
  }

  final doc = await fs.collection('coachApplications').doc(applicationId).get();
  if (!doc.exists) {
    throw Exception('Application not found');
  }

  return CoachApplicationDetail.fromFirestore(doc.id, doc.data() ?? {});
});

/// Update coach application status (approve/reject)
final updateCoachApplicationStatusProvider = FutureProvider.family<
  void,
  (String applicationId, String status, String? rejectionReason)
>((ref, params) async {
  final fs = ref.watch(firestoreInstanceProvider);
  if (fs == null) {
    throw Exception('Firestore not initialized');
  }

  final (applicationId, status, rejectionReason) = params;

  final updateData = <String, dynamic>{
    'status': status,
    'reviewedAt': FieldValue.serverTimestamp(),
  };

  if (status == 'rejected' && rejectionReason != null) {
    updateData['rejectionReason'] = rejectionReason;
  }

  await fs
      .collection('coachApplications')
      .doc(applicationId)
      .update(updateData);

  // Invalidate the stream so UI updates
  ref.invalidate(pendingCoachApplicationsProvider);
});
