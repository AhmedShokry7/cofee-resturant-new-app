import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/loyalty/data/model/reward_model.dart';

LoyaltyRule _rule({
  String? validTo,
  bool isActive = true,
  num rate = 1,
}) => LoyaltyRule.fromDatabase({
  'code': 'base',
  'name_ar': 'أساسي',
  'name_en': 'Base',
  'points_per_currency_unit': rate,
  'is_active': isActive,
  'valid_from': '2024-01-01T00:00:00Z',
  'valid_to': validTo,
});

void main() {
  final now = DateTime.utc(2025, 6, 1);

  test('a rule past valid_to is not effective, the same as place_order()', () {
    final expired = _rule(validTo: '2025-05-01T00:00:00Z');
    final open = _rule(validTo: '2025-07-01T00:00:00Z');
    final forever = _rule();

    expect(expired.isEffectiveAt(now), isFalse);
    expect(open.isEffectiveAt(now), isTrue);
    expect(forever.isEffectiveAt(now), isTrue);
  });

  test('an inactive rule is never effective', () {
    expect(_rule(isActive: false).isEffectiveAt(now), isFalse);
  });

  test('pointsFor floors the amount and survives binary rounding', () {
    // 4.35 * 100 is 434.99999999999994 in binary floating point.
    expect(_rule(rate: 100).pointsFor(4.35), 435);
    expect(_rule(rate: 1).pointsFor(0), 0);
    expect(_rule(rate: 1).pointsFor(12.9), 12);
  });
}
