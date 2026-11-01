import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/loyalty/data/model/loyalty_transaction.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';

/// Guards against the regression this app actually shipped: the UI language
/// was Arabic while parts of the chrome stayed English.
///
/// [app_strings.dart] is parsed rather than reflected on — `dart:mirrors` is
/// unavailable under `flutter test`, and a hand-maintained list of getters would
/// be abandoned the first week. Parsing means a string added tomorrow is
/// covered without touching this file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('app_strings.dart', () {
    final source = File('lib/core/locale/app_strings.dart').readAsStringSync();
    final pairs = _translationPairs(source);

    test(
      'the file really was parsed (guards against a silent regex break)',
      () {
        expect(pairs.length, greaterThan(150));
      },
    );

    test('every Arabic value contains Arabic', () {
      // A value with no Arabic letter at all is an English string that was
      // copied into the Arabic branch, which is the exact bug reported.
      final problems = [
        for (final pair in pairs)
          if (!_hasArabic(_withoutInterpolation(pair.arabic)))
            '${pair.name}: "${pair.arabic}"',
      ];
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('no value is blank', () {
      final problems = [
        for (final pair in pairs)
          if (pair.arabic.trim().isEmpty || pair.english.trim().isEmpty)
            pair.name,
      ];
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('no Arabic value still reads as English', () {
      // Only applies where the Arabic branch is genuinely prose; a format hint
      // or a brand token that is identical in both languages is fine.
      final problems = [
        for (final pair in pairs)
          if (_hasArabic(pair.arabic) &&
              _withoutInterpolation(pair.arabic)
                      .replaceAll(_arabicLetters, '')
                      .trim() ==
                  _withoutInterpolation(pair.english).trim())
            pair.name,
      ];
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('no value mixes Arabic with stray Latin script mid-sentence', () {
      // The auth cubit once shipped "هذا الحساب已被已被禁用" and
      // "هذا الإيميلAlready مسجل": a translation typed once and never checked.
      final problems = <String>[];
      for (final pair in pairs) {
        if (!_hasArabic(_withoutInterpolation(pair.arabic))) continue;
        final latin = _withoutInterpolation(pair.arabic)
            .replaceAll(_arabicLetters, '');
        // Allow digits, punctuation and spaces; a run of letters is a leak.
        if (RegExp('[A-Za-z]{3,}').hasMatch(latin)) {
          problems.add('${pair.name}: "${pair.arabic}"');
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('no value carries a replacement or CJK character', () {
      final problems = [
        for (final pair in pairs)
          if (RegExp('[\uFFFD\u4E00-\u9FFF\uAC00-\uD7AF]')
                  .hasMatch(pair.arabic) ||
              RegExp('[\uFFFD\u4E00-\u9FFF\uAC00-\uD7AF]')
                  .hasMatch(pair.english))
            pair.name,
      ];
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('locale switching reaches model getters', () {
    test('a reason-coded ledger row relabels when the language changes', () {
      final row = LoyaltyTransaction.fromDatabase({
        'id': 'tx-1',
        'points': 10,
        'reason': 'earn_order',
        'created_at': '2026-10-01T10:00:00Z',
      });

      AppLocale.instance.debugSet(AppLanguage.english);
      expect(row.title, S.orderPurchaseLabel);
      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(row.title, S.orderPurchaseLabel);
      expect(row.title, isNot(contains('Order')));
    });

    test('an operator note is shown as written, not translated', () {
      final row = LoyaltyTransaction.fromDatabase({
        'id': 'tx-2',
        'points': 10,
        'reason': 'earn_order',
        'note': 'earned on order ORD-1',
        'created_at': '2026-10-01T10:00:00Z',
      });

      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(row.title, 'earned on order ORD-1');
    });

    test('order status labels differ between the two languages', () {
      for (final status in OrderStatus.values) {
        AppLocale.instance.debugSet(AppLanguage.english);
        final english = status.label;
        AppLocale.instance.debugSet(AppLanguage.arabic);
        expect(status.label, isNot(english), reason: status.name);
      }
    });
  });
}

class _Pair {
  const _Pair(this.name, this.arabic, this.english);
  final String name;
  final String arabic;
  final String english;
}

final _arabicLetters = RegExp('[\u0600-\u06FF]');

bool _hasArabic(String value) => _arabicLetters.hasMatch(value);

/// Removes `$name` / `${name}` placeholders.
///
/// They are code, not text: `$name` is not an English word leaking into an
/// Arabic sentence, and stripping them keeps the checks below about the
/// translation itself.
final _interpolation = RegExp(r'\$\{?[A-Za-z_][A-Za-z0-9_]*\}?');

String _withoutInterpolation(String value) =>
    value.replaceAll(_interpolation, '#');

/// Finds every `_ar ? '…' : '…'` pair in the strings file, together with the
/// getter it belongs to. Covers both the single-line and the wrapped layout.
List<_Pair> _translationPairs(String source) {
  final pair = RegExp(
    r"_ar\s*\?\s*'((?:[^'\\\n]|\\.)*)'\s*:\s*'((?:[^'\\\n]|\\.)*)'",
    dotAll: true,
  );
  final pairs = <_Pair>[];
  for (final match in pair.allMatches(source)) {
    final before = source.substring(0, match.start);
    final name = _lastGetterName(before);
    pairs.add(_Pair(name, match.group(1)!, match.group(2)!));
  }
  return pairs;
}

/// The identifier the pair belongs to, so a failure names the offending getter.
String _lastGetterName(String before) {
  final matches = RegExp(r'String(?: get)? ([A-Za-z_][A-Za-z0-9_]*)')
      .allMatches(before);
  return matches.isEmpty ? '(unknown)' : matches.last.group(1)!;
}
