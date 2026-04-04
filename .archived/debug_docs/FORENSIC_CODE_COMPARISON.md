# 🔬 FORENSIC CODE COMPARISON: Working vs Current

## STATUS: CRITICAL DIFFERENCES FOUND

Last checked: March 27, 2026

---

## FINDING #1: mediaServiceProvider DEFINITIONS

### Working Version (Expected from session notes)
Had **3 separate provider definitions**:
1. `lib/core/providers/service_providers.dart` - Line 28
2. `lib/core/providers/chat_media_upload_provider.dart` - Line 60  
3. `lib/features/dating_onboarding/presentation/screens/dating_audio_summary_screen.dart` - Line 17

### Current Version (ACTUAL STATE)
**Only 1 provider definition exists:**

📍 [lib/core/providers/service_providers.dart](lib/core/providers/service_providers.dart#L28) - **Line 28-31**
```dart
final mediaServiceProvider = Provider<MediaService>((ref) {
  final service = MediaService();
  ref.onDispose(() => service.dispose());
  return service;
});
```

✅ **PROPER DISPOSAL**: Has `ref.onDispose(() => service.dispose())`

---

## FINDING #2: DIRECT MediaService() INSTANTIATION IN profile_screen.dart

### Current Version Uses MULTIPLE DIRECT INSTANTIATIONS (VIOLATIONS):

**📍 Line 3875** - [lib/features/profile/presentation/screens/profile_screen.dart](lib/features/profile/presentation/screens/profile_screen.dart#L3875)
```dart
      final cleanPhotos = <String>[];
      for (final p in _photos) {
        final v = p.trim();
        if (v.isEmpty) continue;
        if (seen.add(v)) cleanPhotos.add(v);
        if (cleanPhotos.length == 6) break;
      }

      // Upload any new local photos to Spaces; keep existing remote URLs intact
      final media = MediaService();  // ❌ DIRECT INSTANTIATION - NO PROVIDER
      final uploadedPhotos = <String>[];
      for (var i = 0; i < cleanPhotos.length; i++) {
        final path = cleanPhotos[i];
        if (path.startsWith('http')) {
          uploadedPhotos.add(path);
          continue;
        }

        final file = File(path);
        if (!await file.exists()) {
          throw StateError('Photo not found: $path');
        }

        final url = await media.uploadProfilePhoto(
          widget.profile.id,
```

**📍 Line 4135** - [lib/features/profile/presentation/screens/profile_screen.dart](lib/features/profile/presentation/screens/profile_screen.dart#L4135)
```dart
                    _photos.removeAt(index);
                    _markDirty();
                    setState(() {});
                  },
                  onAddPhoto: () async {
                    final service = MediaService();  // ❌ DIRECT INSTANTIATION - NO PROVIDER

                    if (_photos.length >= 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You can only add up to 6 photos.'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                      return;
                    }

                    final file = await service.pickImage(context);
```

### ❌ PROBLEM: These bypass the provider system
- No disposal via `ref.onDispose()`
- Creates independent service instances
- Different lifecycle management
- No Riverpod state management

---

## FINDING #3: _ProfileAudioController Implementation

### Current Version DOES HAVE _ProfileAudioController

📍 [lib/features/profile/presentation/screens/profile_screen.dart](lib/features/profile/presentation/screens/profile_screen.dart#L2081-L2375)

The current version has a **sophisticated _ProfileAudioController** class (lines 2081-2375) with:

#### ✅ Advanced Features:
1. **Duration Caching**: `_durationCache` map prevents re-fetching
2. **Firestore Duration Seeding**: `_seededUrls` set to use authoritative timer-based durations
3. **Disk Caching**: `_AudioSourceLock caching` for Android/iOS compatibility
4. **Preloading**: Background buffering for instant playback (line 2248-2276)
5. **Platform-specific handling**: Different logic for Android vs iOS (line 2166-2180)
6. **State tracking**: `isPlaying`, `isLoading`, `hasError`, `position`, `duration`
7. **Listeners pattern**: `addListener()`, `removeListener()`, `_notifyAll()`

#### Key Method: `playOrPause()` - Lines 2280-2330

```dart
Future<void> playOrPause(String url) async {
  final wasError = hasError;           // Track previous error state
  hasError = false;
  final u = url.trim();
  if (u.isEmpty) return;

  try {
    // If the previous attempt for this URL errored, force a full reload
    // instead of entering the same-URL toggle path (player has no source).
    if (currentUrl != u || wasError) {
      currentUrl = u;
      position = Duration.zero;
      duration = _durationCache[u] ?? Duration.zero;

      if (_preloadedUrl == u) {
        _preloadedUrl = null;
        // Verify player is still in a loaded state (Android/ExoPlayer
        // may have released the buffer since preload).
        final ps = _player.processingState;
        if (ps == ja.ProcessingState.ready ||
            ps == ja.ProcessingState.completed) {
          // Already buffered — play instantly, no spinner
          _notifyAll();
          if (ps == ja.ProcessingState.completed) {
            await _player.seek(Duration.zero);
          }
          await _player.play();
        } else {
          // Preloaded buffer lost — do a full load
          debugPrint(
            '[ProfileAudio] preloaded buffer stale (state=$ps), '
            'doing full load',
          );
          isLoading = true;
          _notifyAll();
          final source = await _sourceForUrl(u);
          await _player.setAudioSource(source);
          await _player.play();
        }
        return;
      }

      isLoading = true;
      _notifyAll();
      final source = await _sourceForUrl(u);
      await _player.setAudioSource(source);
      await _player.play();
      return;
    }

    // Same URL — toggle
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ja.ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  } catch (e, st) {
    debugPrint('[ProfileAudio] ❌ playOrPause failed for URL: $u');
    debugPrint('[ProfileAudio] Error: $e');
    debugPrint(
      '[ProfileAudio] Stack: ${st.toString().split('\n').take(5).join('\n')}',
    );
    hasError = true;
    isLoading = false;
    isPlaying = false;
    _notifyAll();
  }
}
```

#### Error Handling in playOrPause():
- ✅ Uses `debugPrint()` NOT `print()`
- ✅ Logs full stack trace (first 5 lines)
- ✅ Clear error prefix: `❌`
- ✅ Sets `hasError = true` for UI to show error state
- ✅ Resets loading/playing state on error
- ✅ Notifies listeners after error

---

## FINDING #4: AdminReviewDetailScreen Error Handling

### Current Version - Line 82

📍 [lib/features/admin_review/presentation/screens/admin_review_detail_screen.dart](lib/features/admin_review/presentation/screens/admin_review_detail_screen.dart#L82-L95)

```dart
  Future<void> _togglePlay(String url) async {
    try {
      // Tap the same track that is currently playing → pause it
      if (_currentlyPlayingUrl == url && _isPlaying) {
        await _media.pauseAudio();
        setState(() {
          _isPlaying = false;
          _isPaused = true;
        });
        return;
      }

      // Tap the same track that was paused → resume it
      if (_currentlyPlayingUrl == url && _isPaused) {
        await _media.resumeAudio();
        setState(() {
          _isPlaying = true;
          _isPaused = false;
        });
        return;
      }

      // Different track (or first play) → stop current, start new
      await _media.stopAudio();
      setState(() {
        _currentlyPlayingUrl = url;
        _isPlaying = true;
        _isPaused = false;
      });
      await _media.playAudioFromUrl(url);
    } catch (e) {
      print('[ADMIN_REVIEW] Audio playback error for $url: $e');  // ⚠️ ISSUE: Uses print()
      setState(() {
        _currentlyPlayingUrl = null;
        _isPlaying = false;
        _isPaused = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio playback failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
```

#### ⚠️ ERROR HANDLING ISSUE:
- **Line 82**: Uses `print()` instead of `debugPrint()`
- `print()` may not appear in release builds
- Session memory indicated this should use `debugPrint()`

#### ✅ What it does well:
- Shows user-facing error via SnackBar
- Resets UI state (`_currentlyPlayingUrl`, `_isPlaying`, `_isPaused`)
- Checks `if (mounted)` before calling ScaffoldMessenger

---

## FINDING #5: MediaService Silent Error Suppression

### Lines with Silent `catch (_)` blocks:

**Line 199** - [lib/core/services/media_service.dart](lib/core/services/media_service.dart#L199)
```dart
  Future<bool> hasHumanFace(String filePath) async {
    try {
      final detector = FaceDetector(/* ... */);
      final faces = await detector.processImage(/* ... */);
      await detector.close();
      return faces.isNotEmpty;
    } catch (_) {     // ❌ SILENT: Returns null without logging
      return null;
    }
  }
```

**Line 272** - [lib/core/services/media_service.dart](lib/core/services/media_service.dart#L272)
```dart
  Future<File?> _cropImage(String sourcePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(/* ... */);
      return croppedFile != null ? File(croppedFile.path) : File(sourcePath);
    } catch (_) {     // ❌ SILENT: Returns source file without logging
      return File(sourcePath);
    }
  }
```

**Line 286** - [lib/core/services/media_service.dart](lib/core/services/media_service.dart#L286)
```dart
  void _startAmplitudeStream() async {
    while (_isRecording) {
      try {
        final amplitude = await _audioRecorder.getAmplitude();
        onRecordingAmplitudeUpdate?.call(/* ... */);
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (_) {   // ❌ SILENT: Just breaks loop without logging
        break;
      }
    }
  }
```

**Line 300** - [lib/core/services/media_service.dart](lib/core/services/media_service.dart#L300)
```dart
  Future<String?> stopRecording() async {
    try {
      _recordingTimer?.cancel();
      if (!_isRecording) return null;
      final path = await _audioRecorder.stop();
      await Future.delayed(const Duration(milliseconds: 500));
      _isRecording = false;
      return path ?? _currentRecordingPath;
    } catch (_) {     // ❌ SILENT: Returns null without logging
      _isRecording = false;
      return null;
    }
  }
```

**Line 355** - [lib/core/services/media_service.dart](lib/core/services/media_service.dart#L355)
```dart
  Future<Duration?> getAudioDuration(String path) async {
    try {
      final duration =
          path.startsWith('http')
              ? await _audioPlayer.setUrl(path)
              : await _audioPlayer.setFilePath(path);

      // Validate duration is reasonable (max 90 seconds for recordings)
      if (duration != null && duration.inSeconds > 90) {
        debugPrint(
          '[MediaService] ⚠️  Audio duration suspicious: ${duration.inSeconds}s, capping to 90s',
        );
        return const Duration(seconds: 90);
      }

      return duration;
    } catch (_) {     // ❌ SILENT: Returns null without logging
      return null;
    }
  }
```

### Impact of Silent Errors:
- Audio playback fails → no error logged
- Face detection fails → returns null silently
- Image cropping fails → returns original file silently
- Amplitude stream fails → stops updating silently
- Recording stops fail → returns null silently

---

## FINDING #6: MediaService Audio Playback - No URL Validation

### Current Implementation - Lines 312-324

📍 [lib/core/services/media_service.dart](lib/core/services/media_service.dart#L312-L324)

```dart
  /// Play audio from file path or URL
  /// Handles both local files and remote URLs with Android compatibility
  Future<void> playAudio(String path) async {
    try {
      // Configure iOS audio session before first play attempt
      await _configureAudioSessionIOS();

      if (path.startsWith('http')) {
        // For URLs, add caching and error handling for Android
        await _audioPlayer.setUrl(path);   // ❌ NO VALIDATION
      } else {
        await _audioPlayer.setFilePath(path);
      }
      await _audioPlayer.play();
    } catch (e) {
      throw MediaException('Failed to play audio: $e');
    }
  }
```

### ❌ Missing Validations:
1. **Empty URL check**: No `if (path.isEmpty) throw ...`
2. **URL format check**: No validation that URL is actually a valid Spaces URL
3. **Timeout handling**: No timeout for remote URLs (could hang indefinitely)
4. **Network check**: No check if device has internet connectivity
5. **Error context**: Generic error message loses the actual error details

### ✅ What exists:
- `_configureAudioSessionIOS()` call before playback
- Basic `startsWith('http')` check

---

## FINDING #7: Audio Session Configuration - Instance-Specific Flag

### Issue: `_audioSessionConfigured` is per-instance

If multiple MediaService instances exist:
- **Instance 1** configures audio session → flag = `true`
- **Instance 2** still has flag = `false`
- **Instance 3** still has flag = `false`
- Each new play attempt on Instance 2 or 3 might try to configure again (or never does)

### Current Implementation doesn't show the `_configureAudioSessionIOS()` method completely

The flag should be **shared globally** or **static**, not instance-specific.

---

## SUMMARY OF FINDINGS

| Finding | Working Ver | Current Ver | Status | Severity |
|---------|-------------|-------------|--------|----------|
| mediaServiceProvider definitions | 3 separate (broken) | 1 provider (fixed) | ✅ FIXED | - |
| Direct MediaService() in profile_screen.dart | N/A | 2 instances (3875, 4135) | ❌ BROKEN | HIGH |
| _ProfileAudioController | N/A | Exists with good error handling | ✅ EXISTS | - |
| AdminReview error logging | debugPrint (expected) | print() | ❌ ISSUE | MEDIUM |
| Silent catch(_) in MediaService | Existed | Still exists (5+ places) | ❌ STILL BROKEN | HIGH |
| URL validation in playAudio() | Missing | Still missing | ❌ NOT FIXED | HIGH |
| Audio session config flag | Instance-specific | Likely still instance-specific | ⚠️ UNCONFIRMED | MEDIUM |

---

## KEY INSIGHTS

### ✅ What's Been Fixed:
1. Multiple mediaServiceProvider definitions consolidated to 1
2. Provider has proper disposal cleanup
3. _ProfileAudioController added with sophisticated error handling
4. Duration validation and caching implemented
5. Android/iOS platform-specific handling added

### ❌ What's Still Broken:
1. Direct MediaService() instantiation bypasses provider in profile_screen.dart (2 places)
2. Silent error suppression in MediaService.catch(_) blocks (5+ places)
3. Missing URL validation before audio playback
4. AdminReviewDetailScreen still uses print() instead of debugPrint()
5. Audio session configuration flag likely still instance-specific

### 🚨 Critical Issues:
1. **Profile photo upload/selection** creates new MediaService instances, no disposal
2. **Audio errors vanish silently** - can't debug failures
3. **Invalid URLs fail without proper validation** - error message quality issues
