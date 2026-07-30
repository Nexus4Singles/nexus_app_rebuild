import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app_v2/core/utils/auth_validators.dart';

void main() {
  group('AuthValidators.username', () {
    test('rejects empty usernames', () {
      expect(AuthValidators.username(''), 'Username is required');
      expect(AuthValidators.username('   '), 'Username is required');
    });

    test('rejects usernames with numbers or symbols', () {
      expect(AuthValidators.username('Ava1'), 'Username can only contain letters');
      expect(AuthValidators.username('Ava_2024'), 'Username can only contain letters');
      expect(AuthValidators.username('Ava Smith'), 'Username can only contain letters');
    });

    test('accepts alphabet-only usernames within the allowed length', () {
      expect(AuthValidators.username('Ava'), isNull);
      expect(AuthValidators.username('Alexander'), isNull);
    });

    test('rejects usernames that are too short or too long', () {
      expect(AuthValidators.username('Ab'), 'Username must be at least 3 characters');
      expect(
        AuthValidators.username('ABCDEFGHIJKLMNOP'),
        'Username must be 12 characters or fewer',
      );
    });
  });
}
