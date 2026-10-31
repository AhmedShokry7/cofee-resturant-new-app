import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/catalog/admin_product_exception.dart';
import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/presentation/order_refusal_reasons.dart';

/// A refusal as the database throws it: the SQLSTATE the function names, and
/// the English technical text no admin reads.
PostgrestException _refusal(
  String code, {
  String message = 'raw postgres text',
}) => PostgrestException(message: message, code: code);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('the shared refusal mapper', () {
    test('names the codes this database actually raises', () {
      expect(
        adminErrorMessage(_refusal('42501')),
        S.errorNoPermission,
      ); // 509 raises in the chain
      expect(adminErrorMessage(_refusal('28000')), S.errorSignInRequired);
      expect(adminErrorMessage(_refusal('23505')), S.errorAlreadyExists);
      expect(
        adminErrorMessage(_refusal('23514')),
        S.errorRejectedValues,
      ); // 270 raises
      expect(
        adminErrorMessage(_refusal('22023')),
        S.errorRejectedValues,
      ); // 263 raises
      expect(adminErrorMessage(_refusal('23502')), S.errorMissingRequiredField);
      expect(adminErrorMessage(_refusal('23503')), S.errorRecordInUse);
      expect(
        adminErrorMessage(_refusal('P0002')),
        S.errorRecordNotFound,
      ); // 117 raises
      expect(
        adminErrorMessage(_refusal('40001')),
        S.errorRecordChangedConcurrently,
      );
    });

    test('keeps the raw database text off the screen', () {
      final message = adminErrorMessage(
        _refusal('42501', message: 'permission denied for table banners'),
      );
      expect(message, isNot(contains('permission denied for table')));
      expect(message, isNot(contains('raw postgres text')));
    });

    test('reads the SQLSTATE of a refusal, and nothing of a plain error', () {
      expect(adminErrorSqlState(_refusal('23505')), '23505');
      expect(adminErrorSqlState(StateError('offline')), isNull);
    });

    test('falls back to the page when the code is unknown', () {
      expect(
        adminErrorMessage(_refusal('99999'), fallback: S.orderActionFailed),
        S.orderActionFailed,
      );
      expect(adminErrorMessage(_refusal('99999')), S.actionFailedUnexpectedly);
    });

    test('falls back for an error that is not a refusal at all', () {
      expect(
        adminErrorMessage(StateError('offline'), fallback: S.orderActionFailed),
        S.orderActionFailed,
      );
      expect(
        adminErrorMessage(StateError('offline')),
        S.actionFailedUnexpectedly,
      );
    });

    test('leaves a message the app already wrote alone', () {
      expect(
        adminErrorMessage(
          const AdminProductException('الصورة أكبر من المسموح'),
        ),
        'الصورة أكبر من المسموح',
      );
    });

    test('says the same reason in Arabic', () {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(
        adminErrorMessage(_refusal('42501')),
        'لا تملك صلاحية لهذا الإجراء.',
      );
      expect(
        adminErrorMessage(StateError('offline')),
        isNot(contains('offline')),
      );
    });
  });

  group('the phrase book of a page', () {
    test('says the reason the order function named', () {
      expect(
        adminErrorMessage(
          _refusal('23514', message: 'insufficient stock for product 7c2e-1'),
          fallback: S.orderActionFailed,
          reasons: orderRefusalReasons(),
        ),
        S.orderRefusalStock,
      );
      expect(
        adminErrorMessage(
          _refusal('42501', message: 'you do not manage this branch'),
          fallback: S.orderActionFailed,
          reasons: orderRefusalReasons(),
        ),
        S.orderRefusalBranch,
      );
    });

    test('prefers the longer phrase of two', () {
      // 200 raises both, and the refunded one also holds the shorter words.
      expect(
        adminErrorMessage(
          _refusal('22023', message: 'refunded order is not editable'),
          reasons: orderRefusalReasons(),
        ),
        S.orderRefusalRefunded,
      );
      expect(
        adminErrorMessage(
          _refusal('22023', message: 'order is not editable'),
          reasons: orderRefusalReasons(),
        ),
        S.orderRefusalNotEditable,
      );
    });

    test('keeps the code reason when no phrase matches', () {
      expect(
        adminErrorMessage(
          _refusal('42501', message: 'missing permission: orders.read'),
          fallback: S.orderActionFailed,
          reasons: orderRefusalReasons(),
        ),
        S.errorNoPermission,
      );
    });
  });
}
