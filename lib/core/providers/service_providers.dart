import 'dart:io';
import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:nexus_app_min_test/core/services/chat_service.dart';

import '../services/media_service.dart';
import '../services/dating_profile_service.dart';
import 'auth_provider.dart';
import 'user_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexus_app_min_test/core/user/current_user_disabled_provider.dart';

// Note: firestoreServiceProvider is in firestore_service_provider.dart

// ============================================================================
// MEDIA SERVICE PROVIDER
// ============================================================================

/// Provider for MediaService instance
final mediaServiceProvider = Provider<MediaService>((ref) {
  final service = MediaService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ============================================================================
// DATING PROFILE SERVICE PROVIDER
// ============================================================================

/// Provider for DatingProfileService instance
class _DatingProfileServiceStub extends DatingProfileService {
  _DatingProfileServiceStub() : super(firestore: FirebaseFirestore.instance);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final datingProfileServiceProvider = Provider<DatingProfileService>((ref) {
  final ready = ref.watch(firebaseReadyProvider);
  final fs = ref.watch(firestoreInstanceProvider);
  if (!ready || fs == null) return _DatingProfileServiceStub();
  return DatingProfileService(firestore: fs);
});

/// Provider to check if dating profile is complete
final isDatingProfileCompleteProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;

  final service = ref.watch(datingProfileServiceProvider);
  return await service.isDatingProfileComplete(userId);
});

/// Provider to check if compatibility quiz is complete
final isCompatibilityCompleteProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;

  final service = ref.watch(datingProfileServiceProvider);
  return await service.isCompatibilityQuizComplete(userId);
});

/// Provider for profile completion percentage
final profileCompletionPercentProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;

  final service = ref.watch(datingProfileServiceProvider);
  return await service.getProfileCompletionPercentage(userId);
});

/// Provider to check if user needs to complete compatibility quiz
final needsCompatibilityQuizProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return false;

  // Singles need to complete compatibility quiz
  // Check if user is single AND hasn't completed the quiz
  final status = user.nexus2?.relationshipStatus ?? '';
  final isSingle =
      status == 'single_never_married' || status == 'divorced_widowed';
  final hasCompletedQuiz = user.compatibilitySetted ?? false;

  return isSingle && !hasCompletedQuiz;
});

// ============================================================================
// CHAT SERVICE PROVIDER
// ============================================================================

// ============================================================================
// CHAT SERVICE PROVIDER
// ============================================================================

class _ChatServiceStub implements ChatService {
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Provider for ChatService instance
final chatServiceProvider = Provider<ChatService>((ref) {
  final ready = ref.watch(firebaseReadyProvider);
  final fs = ref.watch(firestoreInstanceProvider);
  if (!ready || fs == null) return _ChatServiceStub();
  return ChatService(firestore: fs);
});

/// Provider for user's conversations (real-time)
final userConversationsProvider = StreamProvider<List<ChatConversation>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  final chatService = ref.watch(chatServiceProvider);
  return chatService
      .streamUserConversations(userId)
      .handleError((e, st) {
        // Force console visibility of why the Chats list fails.
        // This will print even if the UI shows a generic error.
        // ignore: avoid_print
        debugPrint('[Chats][userConversationsProvider] error=$e');
        // ignore: avoid_print
        debugPrint(st.toString());
      });
});

/// Provider for total unread message count
final totalUnreadCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(0);

  final chatService = ref.watch(chatServiceProvider);
  return chatService.streamTotalUnreadCount(userId);
});

/// Provider for messages in a specific chat (real-time)
final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((
  ref,
  chatId,
) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.streamMessages(chatId);
});

/// Provider for a conversation by chatId (one-shot)
final chatConversationProvider =
    FutureProvider.family<ChatConversation?, String>((ref, chatId) async {
      final ready = ref.watch(firebaseReadyProvider);
      if (!ready) return null;

      final chatService = ref.watch(chatServiceProvider);
      try {
        return await chatService.getConversation(chatId);
      } catch (_) {
        return null;
      }
    });

/// Provider for typing users in a chat
final typingUsersProvider = StreamProvider.family<List<String>, String>((
  ref,
  chatId,
) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.streamTypingUsers(chatId);
});

/// Provider to get or create a conversation with another user
final getOrCreateChatProvider = FutureProvider.family<String, String>((
  ref,
  otherUserId,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw Exception('Not authenticated');

  // Hard gate: disabled users cannot start new chats.
  final isDisabled = await ref.watch(currentUserDisabledProvider.future);
  if (isDisabled) {
    throw StateError('Your account has been disabled by Admin.');
  }

  final chatService = ref.watch(chatServiceProvider);
  return await chatService.createConversation(userId, otherUserId);
});

// ============================================================================
// CHAT NOTIFIER (for sending messages and managing state)
// ============================================================================

/// State notifier for chat operations
class ChatNotifier extends StateNotifier<AsyncValue<void>> {
  final ChatService _chatService;
  final MediaService _mediaService;
  final String _currentUserId;
  final Future<bool> Function() _isDisabled;

  ChatNotifier(
    this._chatService,
    this._mediaService,
    this._currentUserId,
    this._isDisabled,
  ) : super(const AsyncValue.data(null));

  bool _looksLikeHttpUrl(String s) {
    final v = s.trim().toLowerCase();
    return v.startsWith('http://') || v.startsWith('https://');
  }

  bool _isLocalFilePath(String s) {
    if (_looksLikeHttpUrl(s)) return false;
    try {
      return File(s).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Send a text message (optionally includes metadata e.g. reply info)
  Future<ChatMessage?> sendMessage({
    required String chatId,
    required String receiverId,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    state = const AsyncValue.loading();
    try {
      if (await _isDisabled()) {
        throw StateError('Your account has been disabled by Admin.');
      }

      final message = await _chatService.sendMessage(
        chatId: chatId,
        senderId: _currentUserId,
        receiverId: receiverId,
        content: content,
        type: MessageType.text,
        metadata: metadata,
      );

      state = const AsyncValue.data(null);
      return message;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Send an image message (content is a URL for prod; can be a local path in dev)
  Future<ChatMessage?> sendImage({
    required String chatId,
    required String receiverId,
    required String imageUrl,
    String? caption,
    Map<String, dynamic>? metadata,
  }) async {
    state = const AsyncValue.loading();
    try {
      if (await _isDisabled()) {
        throw StateError('Your account has been disabled by Admin.');
      }

      final merged = <String, dynamic>{
        if (metadata != null) ...metadata,
        if (caption != null) 'caption': caption,
      };

      // If caller passed a local file path, upload to Spaces and store the public URL in Firestore.
      String finalImageUrl = imageUrl;
      if (_isLocalFilePath(imageUrl)) {
        finalImageUrl = await _mediaService.uploadChatImage(
          userId: _currentUserId,
          chatId: chatId,
          imageFile: File(imageUrl),
        );
      }

      final message = await _chatService.sendMessage(
        chatId: chatId,
        senderId: _currentUserId,
        receiverId: receiverId,
        content: finalImageUrl,
        type: MessageType.image,
        metadata: merged.isEmpty ? null : merged,
      );

      state = const AsyncValue.data(null);
      return message;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Send an audio message (content is a URL for prod; can be a local path in dev)
  Future<ChatMessage?> sendAudio({
    required String chatId,
    required String receiverId,
    required String audioUrl,
    required int durationSeconds,
    Map<String, dynamic>? metadata,
  }) async {
    state = const AsyncValue.loading();
    try {
      if (await _isDisabled()) {
        throw StateError('Your account has been disabled by Admin.');
      }

      final merged = <String, dynamic>{
        if (metadata != null) ...metadata,
        'duration': durationSeconds,
      };

      // If caller passed a local file path, upload to Spaces and store the public URL in Firestore.
      String finalAudioUrl = audioUrl;
      if (_isLocalFilePath(audioUrl)) {
        finalAudioUrl = await _mediaService.uploadChatAudio(
          userId: _currentUserId,
          chatId: chatId,
          filePath: audioUrl,
        );
      }

      final message = await _chatService.sendMessage(
        chatId: chatId,
        senderId: _currentUserId,
        receiverId: receiverId,
        content: finalAudioUrl,
        type: MessageType.audio,
        metadata: merged,
      );

      state = const AsyncValue.data(null);
      return message;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Mark messages as read in this chat
  Future<void> markAsRead(String chatId) async {
    try {
      await _chatService.markMessagesAsRead(chatId, _currentUserId);
    } catch (_) {
      // Silent fail
    }
  }

  /// Typing indicator
  Future<void> setTyping(String chatId, bool isTyping) async {
    try {
      await _chatService.setTypingStatus(chatId, _currentUserId, isTyping);
    } catch (_) {
      // Silent fail
    }
  }
}

/// Provider for ChatNotifier
final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, AsyncValue<void>>((ref) {
      final chatService = ref.watch(chatServiceProvider);
      final userId = ref.watch(currentUserIdProvider);

      if (userId == null) {
        throw Exception('Not authenticated');
      }

      Future<bool> isDisabled() => ref.read(currentUserDisabledProvider.future);
      final mediaService = ref.watch(mediaServiceProvider);
      return ChatNotifier(chatService, mediaService, userId, isDisabled);
    });

// ============================================================================
// DATING PROFILE NOTIFIER (for profile updates)
// ============================================================================

/// State for dating profile form
class DatingProfileFormState {
  final int? age;
  final String? nationality;
  final String? cityCountry;
  final String? country;
  final String? educationLevel;
  final String? profession;
  final String? church;
  final List<String> hobbies;
  final List<String> desiredQualities;
  final List<String> photos;
  final List<String?> audioUrls; // [audio1, audio2, audio3]
  final String? instagramUsername;
  final String? twitterUsername;
  final String? whatsappNumber;
  final String? facebookUsername;
  final String? telegramUsername;
  final String? snapchatUsername;
  final bool isSaving;
  final String? error;

  const DatingProfileFormState({
    this.age,
    this.nationality,
    this.cityCountry,
    this.country,
    this.educationLevel,
    this.profession,
    this.church,
    this.hobbies = const [],
    this.desiredQualities = const [],
    this.photos = const [],
    this.audioUrls = const [null, null, null],
    this.instagramUsername,
    this.twitterUsername,
    this.whatsappNumber,
    this.facebookUsername,
    this.telegramUsername,
    this.snapchatUsername,
    this.isSaving = false,
    this.error,
  });

  DatingProfileFormState copyWith({
    int? age,
    String? nationality,
    String? cityCountry,
    String? country,
    String? educationLevel,
    String? profession,
    String? church,
    List<String>? hobbies,
    List<String>? desiredQualities,
    List<String>? photos,
    List<String?>? audioUrls,
    String? instagramUsername,
    String? twitterUsername,
    String? whatsappNumber,
    String? facebookUsername,
    String? telegramUsername,
    String? snapchatUsername,
    bool? isSaving,
    String? error,
  }) {
    return DatingProfileFormState(
      age: age ?? this.age,
      nationality: nationality ?? this.nationality,
      cityCountry: cityCountry ?? this.cityCountry,
      country: country ?? this.country,
      educationLevel: educationLevel ?? this.educationLevel,
      profession: profession ?? this.profession,
      church: church ?? this.church,
      hobbies: hobbies ?? this.hobbies,
      desiredQualities: desiredQualities ?? this.desiredQualities,
      photos: photos ?? this.photos,
      audioUrls: audioUrls ?? this.audioUrls,
      instagramUsername: instagramUsername ?? this.instagramUsername,
      twitterUsername: twitterUsername ?? this.twitterUsername,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      facebookUsername: facebookUsername ?? this.facebookUsername,
      telegramUsername: telegramUsername ?? this.telegramUsername,
      snapchatUsername: snapchatUsername ?? this.snapchatUsername,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }

  bool get isStep1Complete => age != null && age! >= 21;

  bool get isStep2Complete =>
      nationality != null &&
      cityCountry != null &&
      country != null &&
      educationLevel != null &&
      profession != null;

  bool get isStep3Complete => hobbies.isNotEmpty;

  bool get isStep4Complete => desiredQualities.isNotEmpty;

  bool get isStep5Complete => photos.length >= 2;

  bool get isStep6Complete =>
      audioUrls[0] != null && audioUrls[1] != null && audioUrls[2] != null;

  bool get isStep7Complete =>
      (instagramUsername?.isNotEmpty ?? false) ||
      (twitterUsername?.isNotEmpty ?? false) ||
      (whatsappNumber?.isNotEmpty ?? false) ||
      (facebookUsername?.isNotEmpty ?? false) ||
      (telegramUsername?.isNotEmpty ?? false) ||
      (snapchatUsername?.isNotEmpty ?? false);

  bool get isComplete =>
      isStep1Complete &&
      isStep2Complete &&
      isStep3Complete &&
      isStep4Complete &&
      isStep5Complete &&
      isStep6Complete &&
      isStep7Complete;
}

/// Notifier for dating profile form
class DatingProfileFormNotifier extends StateNotifier<DatingProfileFormState> {
  final DatingProfileService _service;
  // ignore: unused_field
  final MediaService _mediaService;
  final String _userId;

  DatingProfileFormNotifier(this._service, this._mediaService, this._userId)
    : super(const DatingProfileFormState());

  // Setters for each field
  void setAge(int age) => state = state.copyWith(age: age);
  void setNationality(String value) =>
      state = state.copyWith(nationality: value);
  void setCityCountry(String value) =>
      state = state.copyWith(cityCountry: value);
  void setCountry(String value) => state = state.copyWith(country: value);
  void setEducationLevel(String value) =>
      state = state.copyWith(educationLevel: value);
  void setProfession(String value) => state = state.copyWith(profession: value);
  void setChurch(String? value) => state = state.copyWith(church: value);

  void toggleHobby(String hobby) {
    final hobbies = List<String>.from(state.hobbies);
    if (hobbies.contains(hobby)) {
      hobbies.remove(hobby);
    } else if (hobbies.length < 5) {
      hobbies.add(hobby);
    }
    state = state.copyWith(hobbies: hobbies);
  }

  void toggleQuality(String quality) {
    final qualities = List<String>.from(state.desiredQualities);
    if (qualities.contains(quality)) {
      qualities.remove(quality);
    } else if (qualities.length < 8) {
      // Max 8 qualities
      qualities.add(quality);
    }
    state = state.copyWith(desiredQualities: qualities);
  }

  void addPhoto(String url) {
    if (state.photos.length < 4) {
      state = state.copyWith(photos: [...state.photos, url]);
    }
  }

  void removePhoto(int index) {
    final photos = List<String>.from(state.photos);
    if (index < photos.length) {
      photos.removeAt(index);
      state = state.copyWith(photos: photos);
    }
  }

  void setAudioUrl(int index, String url) {
    final audioUrls = List<String?>.from(state.audioUrls);
    audioUrls[index] = url;
    state = state.copyWith(audioUrls: audioUrls);
  }

  void setInstagram(String? value) =>
      state = state.copyWith(instagramUsername: value);
  void setTwitter(String? value) =>
      state = state.copyWith(twitterUsername: value);
  void setWhatsapp(String? value) =>
      state = state.copyWith(whatsappNumber: value);
  void setFacebook(String? value) =>
      state = state.copyWith(facebookUsername: value);
  void setTelegram(String? value) =>
      state = state.copyWith(telegramUsername: value);
  void setSnapchat(String? value) =>
      state = state.copyWith(snapchatUsername: value);

  /// Save complete profile
  Future<bool> saveCompleteProfile() async {
    if (!state.isComplete) {
      state = state.copyWith(error: 'Please complete all required fields');
      return false;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      await _service.saveCompleteDatingProfile(
        _userId,
        age: state.age!,
        nationality: state.nationality!,
        cityCountry: state.cityCountry!,
        country: state.country!,
        educationLevel: state.educationLevel!,
        profession: state.profession!,
        church: state.church,
        hobbies: state.hobbies,
        desiredQualities: state.desiredQualities,
        photoUrls: state.photos,
        audio1Url: state.audioUrls[0],
        audio2Url: state.audioUrls[1],
        audio3Url: state.audioUrls[2],
        instagramUsername: state.instagramUsername,
        twitterUsername: state.twitterUsername,
        whatsappNumber: state.whatsappNumber,
        facebookUsername: state.facebookUsername,
        telegramUsername: state.telegramUsername,
        snapchatUsername: state.snapchatUsername,
      );

      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  /// Save individual step
  Future<bool> saveStep(int step) async {
    state = state.copyWith(isSaving: true, error: null);

    try {
      switch (step) {
        case 1:
          await _service.saveAge(_userId, state.age!);
          break;
        case 2:
          await _service.saveExtraInfo(
            _userId,
            nationality: state.nationality!,
            cityCountry: state.cityCountry!,
            country: state.country!,
            educationLevel: state.educationLevel!,
            profession: state.profession!,
            church: state.church,
          );
          break;
        case 3:
          await _service.saveHobbies(_userId, state.hobbies);
          break;
        case 4:
          await _service.saveDesiredQualities(_userId, state.desiredQualities);
          break;
        case 5:
          await _service.savePhotos(_userId, state.photos);
          break;
        case 6:
          await _service.saveAudioRecordings(
            _userId,
            audio1Url: state.audioUrls[0],
            audio2Url: state.audioUrls[1],
            audio3Url: state.audioUrls[2],
          );
          break;
        case 7:
          await _service.saveContactInfo(
            _userId,
            instagramUsername: state.instagramUsername,
            twitterUsername: state.twitterUsername,
            whatsappNumber: state.whatsappNumber,
            facebookUsername: state.facebookUsername,
            telegramUsername: state.telegramUsername,
            snapchatUsername: state.snapchatUsername,
          );
          break;
      }

      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }
}

/// Provider for dating profile form
final datingProfileFormProvider =
    StateNotifierProvider<DatingProfileFormNotifier, DatingProfileFormState>((
      ref,
    ) {
      final service = ref.watch(datingProfileServiceProvider);
      final mediaService = ref.watch(mediaServiceProvider);
      final userId = ref.watch(currentUserIdProvider);

      if (userId == null) {
        throw Exception('Not authenticated');
      }

      return DatingProfileFormNotifier(service, mediaService, userId);
    });
