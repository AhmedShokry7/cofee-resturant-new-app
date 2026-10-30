import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// الرفض بحروفه: الشاشة لا تخترع سببًا ولا تُلطّف واحدًا.
void main() {
  group('hrRefusalOf', () {
    test('carries the SQLSTATE and the text of the rule', () {
      final refusal = hrRefusalOf(
        PostgrestException(
          message: 'missing permission: hr.payroll.read',
          code: '42501',
        ),
      );

      expect(refusal.sqlState, '42501');
      expect(refusal.isPermission, isTrue);
      expect(refusal.message, 'missing permission: hr.payroll.read');
    });

    test('a code the rule did not send stays empty, never guessed', () {
      final refusal = hrRefusalOf(Exception('socket hung up'));

      expect(refusal.sqlState, isEmpty);
      expect(refusal.isPermission, isFalse);
      expect(refusal.message, contains('socket hung up'));
    });

    test('an already-mapped refusal is not wrapped twice', () {
      final first = HrRefusal(sqlState: 'P0002', message: 'payslip not found');

      expect(hrRefusalOf(first), same(first));
    });
  });

  group('hrRefusalMessage', () {
    test('the longest key wins so the specific text survives', () {
      expect(
        hrRefusalMessage(
          HrRefusal(
            sqlState: '22023',
            message: 'attributed employee not found or inactive',
          ),
        ),
        S.hrAttributedNotFound,
      );
      expect(
        hrRefusalMessage(
          HrRefusal(sqlState: 'P0002', message: 'employee not found'),
        ),
        S.hrEmployeeNotFound,
      );
    });

    test('a detail the rule appended still matches', () {
      expect(
        hrRefusalMessage(
          HrRefusal(
            sqlState: '42501',
            message: 'missing permission: hr.attendance.read for branch 7',
          ),
        ),
        S.hrMissingPermission,
      );
      expect(
        hrRefusalMessage(
          HrRefusal(
            sqlState: '22023',
            message: 'unknown discrepancy action: x',
          ),
        ),
        S.hrUnknownDiscrepancyAction,
      );
    });

    test('a refusal the screen does not know is printed verbatim', () {
      const raw = 'some brand new rule text nobody mapped yet';

      expect(
        hrRefusalMessage(const HrRefusal(sqlState: '23514', message: raw)),
        raw,
      );
    });

    test('every mapped key resolves to a real localized label', () {
      // رسالة فارغة أو `null` كانت تمرّ في الاختبار وتترك شريطًا أبيض أمام المدير.
      for (final wire in <String>[
        'not authenticated',
        'employee not found',
        'already clocked in',
        'overlapping work schedule',
        'insufficient leave balance',
        'only a calculated run can be approved',
        'advance amount must be positive',
        'cashier deductions are disabled in the HR settings',
        'unknown time zone',
      ]) {
        expect(
          hrRefusalMessage(HrRefusal(sqlState: '22023', message: wire)),
          isNot(wire),
          reason: wire,
        );
      }
    });
  });
}
