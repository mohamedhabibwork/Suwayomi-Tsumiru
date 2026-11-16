import 'package:flutter_test/flutter_test.dart';
import 'package:tsumiru/src/features/settings/presentation/security/security_settings_provider.dart';

void main() {
  group('computeLockCooldownSeconds', () {
    test('returns 0 for fewer than 3 failed attempts', () {
      expect(computeLockCooldownSeconds(0), 0);
      expect(computeLockCooldownSeconds(1), 0);
      expect(computeLockCooldownSeconds(2), 0);
    });

    test('returns exponential tiers for 3+ failed attempts', () {
      expect(computeLockCooldownSeconds(3), 5);
      expect(computeLockCooldownSeconds(4), 15);
      expect(computeLockCooldownSeconds(5), 30);
      expect(computeLockCooldownSeconds(6), 60);
      expect(computeLockCooldownSeconds(10), 60);
    });
  });
}
