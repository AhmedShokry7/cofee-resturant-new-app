import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/pos/data/repositories/admin_pos_repository.dart';
import 'package:admin_app/features/pos/domain/entities/pos_shift.dart';
import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_format.dart';

/// Answers the drawer functions with the body PostgREST really sends when a
/// shift function raises, so the mapping under test is the one the app sees.
class _ShiftErrorClient extends http.BaseClient {
  _ShiftErrorClient(this.code, this.message);

  final String code;
  final String message;

  String? rpcName;
  Object? movementAmount;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.startsWith('/rest/v1/rpc/')) {
      rpcName = path.substring('/rest/v1/rpc/'.length);
      if (request is http.Request) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        movementAmount = body['p_amount'];
      }
    }
    final bytes = utf8.encode(
      jsonEncode(<String, dynamic>{
        'code': code,
        'message': message,
        'details': null,
        'hint': null,
      }),
    );
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      400,
      headers: <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
      request: request,
    );
  }
}

/// Rejects one cash out and reports which failure the repository produced.
Future<PosShiftFailure> _cashOutFailure(
  String code,
  String message, {
  _ShiftErrorClient? client,
}) async {
  final httpClient = client ?? _ShiftErrorClient(code, message);
  final supabase = SupabaseClient(
    'https://example.supabase.co',
    'publishable-test-key',
    httpClient: httpClient,
  );
  addTearDown(supabase.dispose);

  try {
    await AdminPosRepository(supabase).recordCashMovement(
      shiftId: '7a000000-0000-4000-8000-000000000001',
      kind: PosCashMovementKind.cashOut,
      amount: 500,
      reason: 'إغلاق حساب مع الصراف',
    );
    return fail('the withdrawal was expected to be rejected');
  } on PosShiftException catch (error) {
    expect(error.message, message);
    return error.failure;
  }
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  test('a withdrawal the drawer cannot cover has its own failure', () async {
    expect(
      await _cashOutFailure('22023', 'cash out exceeds the drawer'),
      PosShiftFailure.insufficientDrawerCash,
    );
  });

  test('the rejected amount is still sent to the server untouched', () async {
    final client = _ShiftErrorClient('22023', 'cash out exceeds the drawer');
    await _cashOutFailure(
      '22023',
      'cash out exceeds the drawer',
      client: client,
    );

    expect(client.rpcName, 'admin_pos_record_cash_movement');
    expect(client.movementAmount, 500);
  });

  group('unrelated shift errors keep their existing meaning', () {
    test('an unknown invalid parameter', () async {
      expect(
        await _cashOutFailure('22023', 'invalid input syntax for type numeric'),
        PosShiftFailure.invalid,
      );
    });

    test('a shift that is already closed', () async {
      expect(
        await _cashOutFailure(
          '23514',
          'violates check constraint "ck_pos_shift_closed"',
        ),
        PosShiftFailure.alreadyClosed,
      );
    });

    test('another check violation', () async {
      expect(
        await _cashOutFailure(
          '23514',
          'violates check constraint "ck_pos_shift_variance"',
        ),
        PosShiftFailure.invalid,
      );
    });

    test('a cashier without the permission', () async {
      expect(
        await _cashOutFailure('42501', 'missing permission: pos.manage'),
        PosShiftFailure.permissionDenied,
      );
    });

    test('a branch that is out of scope', () async {
      expect(
        await _cashOutFailure('P0002', 'branch not available'),
        PosShiftFailure.branchUnavailable,
      );
    });

    test('an unexpected database error', () async {
      expect(
        await _cashOutFailure('23505', 'duplicate key value violates'),
        PosShiftFailure.failed,
      );
    });
  });

  group('the cashier reads one plain sentence', () {
    test('in Arabic and in English, with no database text', () async {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(
        posShiftFailureMessage(PosShiftFailure.insufficientDrawerCash),
        'لا يمكن سحب نقد أكثر من المتاح في الدرج.',
      );

      AppLocale.instance.debugSet(AppLanguage.english);
      expect(
        posShiftFailureMessage(PosShiftFailure.insufficientDrawerCash),
        'You cannot withdraw more cash than the drawer holds.',
      );

      for (final internal in ['22023', 'constraint', 'cash out exceeds']) {
        expect(
          posShiftFailureMessage(PosShiftFailure.insufficientDrawerCash),
          isNot(contains(internal)),
        );
      }
    });

    test('and every other shift failure keeps its own sentence', () {
      final sentences = <PosShiftFailure, String>{
        PosShiftFailure.permissionDenied: S.posShiftPermissionDenied,
        PosShiftFailure.notFound: S.posShiftNotFound,
        PosShiftFailure.alreadyClosed: S.posShiftAlreadyClosed,
        PosShiftFailure.invalid: S.posShiftInvalid,
        PosShiftFailure.failed: S.posShiftFailed,
      };
      sentences.forEach((failure, sentence) {
        expect(posShiftFailureMessage(failure), sentence);
      });
      expect(
        posShiftFailureMessage(null),
        S.posShiftFailed,
        reason: 'the generic answer still covers a failure the app never saw',
      );
    });
  });
}
