/// Test script to verify assessment ID routing logic
void main() {
  final testCases = [
    ('singles_readiness', 'singlesReadiness'),
    ('remarriage_readiness_divorced', 'remarriageDivorced'),
    ('remarriage_readiness_widowed', 'remarriageWidowed'),
    ('marriage_health_check', 'marriageHealthCheck'),
  ];

  for (final (assessmentId, expectedConfig) in testCases) {
    String? result;

    if (assessmentId.contains('singles') ||
        assessmentId.contains('single_never_married')) {
      result = 'singlesReadiness';
    } else if (assessmentId.contains('marriage') &&
        !assessmentId.contains('remarriage')) {
      result = 'marriageHealthCheck';
    } else if (assessmentId.contains('divorced') ||
        assessmentId.contains('remarriage_divorced')) {
      result = 'remarriageDivorced';
    } else if (assessmentId.contains('widowed') ||
        assessmentId.contains('remarriage_widowed')) {
      result = 'remarriageWidowed';
    }

    final status = result == expectedConfig ? '✅' : '❌';
    print('$status $assessmentId → $result (expected: $expectedConfig)');
  }
}
