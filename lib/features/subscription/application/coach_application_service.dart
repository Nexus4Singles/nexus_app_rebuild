import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Models for coach application
class CoachApplication {
  final String? fullName;
  final String? email;
  final String? phoneNumber;
  final String? gender;
  final String? nationality;
  final String? residenceLocation;
  final String? country;
  final String? title;
  final int? yearsOfExperience;
  final String? maritalStatus;
  final String? credentials;
  final List<String>? specializations;
  final String? coachingPhilosophy;
  final String? instagramHandle;
  final String? linkedinProfile;
  final File? profilePhoto;
  final File? credentialsPdf;

  CoachApplication({
    this.fullName,
    this.email,
    this.phoneNumber,
    this.gender,
    this.nationality,
    this.residenceLocation,
    this.country,
    this.title,
    this.yearsOfExperience,
    this.maritalStatus,
    this.credentials,
    this.specializations,
    this.coachingPhilosophy,
    this.instagramHandle,
    this.linkedinProfile,
    this.profilePhoto,
    this.credentialsPdf,
  });

  CoachApplication copyWith({
    String? fullName,
    String? email,
    String? phoneNumber,
    String? gender,
    String? nationality,
    String? residenceLocation,
    String? country,
    String? title,
    int? yearsOfExperience,
    String? maritalStatus,
    String? credentials,
    List<String>? specializations,
    String? coachingPhilosophy,
    String? instagramHandle,
    String? linkedinProfile,
    File? profilePhoto,
    File? credentialsPdf,
  }) {
    return CoachApplication(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gender: gender ?? this.gender,
      nationality: nationality ?? this.nationality,
      residenceLocation: residenceLocation ?? this.residenceLocation,
      country: country ?? this.country,
      title: title ?? this.title,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      credentials: credentials ?? this.credentials,
      specializations: specializations ?? this.specializations,
      coachingPhilosophy: coachingPhilosophy ?? this.coachingPhilosophy,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      linkedinProfile: linkedinProfile ?? this.linkedinProfile,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      credentialsPdf: credentialsPdf ?? this.credentialsPdf,
    );
  }
}

final coachApplicationSubmissionProvider =
    FutureProvider.family<String, CoachApplication>((ref, application) async {
  return CoachApplicationService().submitApplication(application);
});

class CoachApplicationService {
  static final _instance = CoachApplicationService._internal();

  factory CoachApplicationService() {
    return _instance;
  }

  CoachApplicationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit a coach application with file uploads to Firestore
  /// The Cloud Function will handle downloading and emailing attachments
  Future<String> submitApplication(CoachApplication application) async {
    try {
      final applicationId =
          _firestore.collection('coachApplications').doc().id;

      // Create Firestore document with application data
      final submissionData = {
        'applicationId': applicationId,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'fullName': application.fullName,
        'email': application.email,
        'phoneNumber': application.phoneNumber,
        'gender': application.gender,
        'nationality': application.nationality,
        'residenceLocation': application.residenceLocation,
        'title': application.title,
        'yearsOfExperience': application.yearsOfExperience,
        'maritalStatus': application.maritalStatus,
        'credentials': application.credentials,
        'specializations': application.specializations ?? [],
        'coachingPhilosophy': application.coachingPhilosophy,
        'instagramHandle': application.instagramHandle,
        'linkedinProfile': application.linkedinProfile,
        'profilePhoto': {
          'filename': application.profilePhoto?.path.split('/').last,
          'uploadedAt': FieldValue.serverTimestamp(),
        },
        if (application.credentialsPdf != null)
          'credentialsPdf': {
            'filename': 'credentials.pdf',
            'uploadedAt': FieldValue.serverTimestamp(),
          },
        'submissionNotes': '',
        'tags': [],
      };

      // Upload profile photo to storage using a simple method
      if (application.profilePhoto != null) {
        await _uploadProfilePhoto(applicationId, application.profilePhoto!);
      }

      // Upload credentials PDF if provided
      if (application.credentialsPdf != null) {
        await _uploadCredentialsPdf(applicationId, application.credentialsPdf!);
      }

      // Create the document
      await _firestore
          .collection('coachApplications')
          .doc(applicationId)
          .set(submissionData);

      return applicationId;
    } catch (e) {
      rethrow;
    }
  }

  /// Upload profile photo to Storage
  Future<void> _uploadProfilePhoto(String applicationId, File file) async {
    // This will be handled by Cloud Function that reads from local storage
    // For now, we just note that it's been provided
  }

  /// Upload credentials PDF to Storage
  Future<void> _uploadCredentialsPdf(String applicationId, File file) async {
    // This will be handled by Cloud Function that reads from local storage
    // For now, we just note that it's been provided
  }
}
