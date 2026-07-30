import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app_v2/core/services/dating_profile_service.dart';

void main() {
  group('DatingProfileService.buildModerationUpdates', () {
    test('does not reset verification status for profile updates', () {
      final updates = DatingProfileService.buildModerationUpdates(
        photoUrls: ['photo-1.jpg'],
        audioUrls: ['audio-1.mp3'],
      );

      expect(updates.containsKey('dating.verificationStatus'), isFalse);
      expect(updates.containsKey('dating.pendingAt'), isFalse);
      expect(updates.containsKey('dating.verifiedAt'), isFalse);
      expect(updates.containsKey('dating.rejectedAt'), isFalse);
      expect(updates['dating.reviewPack'], isA<Map<String, dynamic>>());
    });
  });
}
