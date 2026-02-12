import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
    print('[DEBUG] Starting coach application submission...');
    try {
      final applicationId = _firestore.collection('coachApplications').doc().id;

      // Create Firestore document with application data
      final submissionData = <String, dynamic>{
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
        'profilePhoto': <String, dynamic>{
          'url': '', // Will be updated after upload
          'filename': application.profilePhoto?.path.split('/').last,
          'uploadedAt': FieldValue.serverTimestamp(),
        },
        'submissionNotes': '',
        'tags': [],
      };

      if (application.credentialsPdf != null) {
        submissionData['credentialsPdf'] = <String, dynamic>{
          'url': '', // Will be updated after upload
          'filename': 'credentials.pdf',
          'uploadedAt': FieldValue.serverTimestamp(),
        };
      }

      // Upload profile photo to Firebase Storage with timeout
      if (application.profilePhoto != null) {
        final user = FirebaseAuth.instance.currentUser;
        print('[DEBUG] Uploading profile photo...');
        if (user == null) {
          print('[ERROR] No authenticated user. Cannot upload.');
        } else {
          print('[DEBUG] Authenticated user UID: \'${user.uid}\'');
        }
        try {
          final photoUrl = await _uploadProfilePhoto(
            applicationId,
            application.profilePhoto!,
          ).timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw Exception(
                'Profile photo upload timed out. Please check your connection and try again.',
              );
            },
          );
          print('[DEBUG] Profile photo uploaded: $photoUrl');
          (submissionData['profilePhoto'] as Map<String, dynamic>)['url'] =
              photoUrl;
        } catch (e) {
          print('[ERROR] Profile photo upload failed: $e');
          rethrow;
        }
      }

      // Upload credentials PDF if provided, with timeout
      if (application.credentialsPdf != null) {
        print('[DEBUG] Uploading credentials PDF...');
        try {
          final pdfUrl = await _uploadCredentialsPdf(
            applicationId,
            application.credentialsPdf!,
          ).timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw Exception(
                'Credentials PDF upload timed out. Please check your connection and try again.',
              );
            },
          );
          print('[DEBUG] Credentials PDF uploaded: $pdfUrl');
          (submissionData['credentialsPdf'] as Map<String, dynamic>)['url'] =
              pdfUrl;
        } catch (e) {
          print('[ERROR] Credentials PDF upload failed: $e');
          rethrow;
        }
      }

      print('[DEBUG] Creating Firestore document for application...');
      await _firestore
          .collection('coachApplications')
          .doc(applicationId)
          .set(submissionData);

      print('[DEBUG] Application submitted successfully!');
      return applicationId;
    } catch (e, stack) {
      print('[ERROR] Application submission failed: $e');
      print(stack);
      rethrow;
    }
  }

  /// Upload profile photo to Firebase Storage and return public URL
  Future<String> _uploadProfilePhoto(String applicationId, File file) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Upload to Firebase Storage: coaches/{userId}/profile_photo_{timestamp}.jpg
      final fileName =
          'profile_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final reference = FirebaseStorage.instance.ref(
        'coaches/${user.uid}/$fileName',
      );
      print(
        '[DEBUG] Storage ref: ${reference.fullPath}, bucket: ${reference.bucket}',
      );

      // Additional file checks
      final exists = await file.exists();
      final length = exists ? await file.length() : 0;
      print(
        '[DEBUG] File path: ${file.path}, exists: $exists, length: $length bytes',
      );
      if (!exists || length == 0) {
        throw Exception('Profile photo file does not exist or is empty.');
      }

      final uploadTask = reference.putFile(file);
      final snapshot = await uploadTask;

      // Get the public download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('Profile photo uploaded to Firebase Storage: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile photo: $e');
      rethrow;
    }
  }

  /// Upload credentials PDF to Firebase Storage and return public URL
  Future<String> _uploadCredentialsPdf(String applicationId, File file) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Upload to Firebase Storage: coaches/{userId}/credentials_{timestamp}.pdf
      final fileName =
          'credentials_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final reference = FirebaseStorage.instance.ref(
        'coaches/${user.uid}/$fileName',
      );

      final uploadTask = reference.putFile(file);
      final snapshot = await uploadTask;

      // Get the public download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('Credentials PDF uploaded to Firebase Storage: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading credentials PDF: $e');
      rethrow;
    }
  }
}
