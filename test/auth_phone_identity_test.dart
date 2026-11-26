import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/auth/data/model/auth_form_rules.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';

void main() {
  group('customer phone identity', () {
    test('normalizes Saudi local and international spellings to E.164', () {
      expect(AuthFormRules.e164Of('050 123 4567'), '+966501234567');
      expect(AuthFormRules.e164Of('50-123-4567'), '+966501234567');
      expect(AuthFormRules.e164Of('+966 50 123 4567'), '+966501234567');
      expect(AuthFormRules.e164Of('00966501234567'), '+966501234567');
    });

    test('rejects an empty or too short number', () {
      expect(AuthFormRules.e164Of(''), isNull);
      expect(AuthFormRules.e164Of('123'), isNull);
    });

    test('a phone is unverified unless Auth explicitly confirms it', () {
      const oldAccount = AuthUser(id: 'customer-1', phone: '+966501234567');
      const verifiedAccount = AuthUser(
        id: 'customer-2',
        phone: '+966501234567',
        phoneVerified: true,
      );

      expect(oldAccount.phoneVerified, isFalse);
      expect(verifiedAccount.phoneVerified, isTrue);
    });
  });
}
