import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/staff/data/repositories/admin_staff_repository.dart';
import 'package:admin_app/features/staff/domain/entities/staff_invite_outcome.dart';
import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';

import 'helpers/stub_supabase_client.dart';

PostgrestException _denied() =>
    PostgrestException(message: 'permission denied', code: '42501');

/// The same refusal reasons `admin_invite_staff` answers with, tested from the
/// row that carries them to the outcome the screen reads.
void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  const token = '3f6a2b1e-8c4d-4e5f-9a0b-1c2d3e4f5a6b';

  StaffRepository repository({
    Map<String, Object?> responses = const <String, Object?>{},
    Map<String, Object> errors = const <String, Object>{},
  }) => AdminStaffRepository(
    StubSupabaseFunctions(responses: responses, errors: errors),
  );

  test('a created invitation sends the four named params', () async {
    final client = StubSupabaseFunctions(
      responses: <String, Object?>{
        'admin_invite_staff': <String, dynamic>{
          'ok': true,
          'invitation_id': 'inv-1',
          'token': token,
          'email': 'chef@example.com',
        },
      },
    );

    final result = await AdminStaffRepository(client).inviteStaff(
      email: 'chef@example.com',
      fullName: 'Chef One',
      roleCode: 'manager',
    );

    expect(client.params['admin_invite_staff'], <String, dynamic>{
      'p_email': 'chef@example.com',
      'p_full_name': 'Chef One',
      'p_role_code': 'manager',
      // فراغ يعني «دعوة بلا فرع»: الدالة نفسها تقرر من يجوز له ذلك.
      'p_branch_id': null,
    });
    expect(result.isSuccess, isTrue);
    expect(result.invitationId, 'inv-1');
    expect(result.code, token);
    expect(result.email, 'chef@example.com');
  });

  test('the code arrives from the write, not from a second read', () async {
    final client = StubSupabaseFunctions(
      responses: <String, Object?>{
        'admin_invite_staff': <String, dynamic>{
          'ok': true,
          'invitation_id': 'inv-1',
          'token': token,
          'email': 'chef@example.com',
        },
      },
    );

    await AdminStaffRepository(client).inviteStaff(
      email: 'chef@example.com',
      fullName: 'Chef One',
      roleCode: 'manager',
      branchId: 'branch-1',
    );

    expect(client.events, ['rpc:admin_invite_staff']);
    expect(client.params['admin_invite_staff']!['p_branch_id'], 'branch-1');
  });

  test(
    'every refusal reason of the create function has its own outcome',
    () async {
      final cases = <String, StaffInviteOutcome>{
        'invalid_email': StaffInviteOutcome.invalidEmail,
        'invalid_name': StaffInviteOutcome.invalidName,
        'unknown_role': StaffInviteOutcome.unknownRole,
        'owner_only': StaffInviteOutcome.ownerOnly,
        'not_your_branch': StaffInviteOutcome.notYourBranch,
        'unknown_branch': StaffInviteOutcome.unknownBranch,
        'already_invited': StaffInviteOutcome.alreadyInvited,
        'already_staff': StaffInviteOutcome.alreadyStaff,
        'not_found': StaffInviteOutcome.notFound,
        'not_pending': StaffInviteOutcome.notPending,
        'a_reason_no_screen_knows': StaffInviteOutcome.failed,
      };
      for (final entry in cases.entries) {
        final result =
            await repository(
              responses: {
                'admin_invite_staff': {'ok': false, 'reason': entry.key},
              },
            ).inviteStaff(
              email: 'a@example.com',
              fullName: 'A',
              roleCode: 'cashier',
            );
        expect(result.outcome, entry.value, reason: entry.key);
        expect(result.isSuccess, isFalse, reason: entry.key);
      }
    },
  );

  test('a duplicate invitation keeps the row the screen can reopen', () async {
    final result = await repository(
      responses: <String, Object?>{
        'admin_invite_staff': <String, dynamic>{
          'ok': false,
          'reason': 'already_invited',
          'invitation_id': 'inv-9',
        },
      },
    ).inviteStaff(email: 'a@example.com', fullName: 'A', roleCode: 'cashier');

    expect(result.outcome, StaffInviteOutcome.alreadyInvited);
    expect(result.invitationId, 'inv-9');
  });

  test(
    'the privilege wall is a denial and any other fault is a failure',
    () async {
      expect(
        (await repository(errors: {'admin_invite_staff': _denied()})
                .inviteStaff(
                  email: 'a@example.com',
                  fullName: 'A',
                  roleCode: 'cashier',
                ))
            .outcome,
        StaffInviteOutcome.permissionDenied,
      );
      expect(
        await repository(
          errors: {
            'admin_cancel_invitation': PostgrestException(
              message: 'deadlock',
              code: '40P01',
            ),
          },
        ).cancelInvitation('inv-1'),
        StaffInviteOutcome.failed,
      );
      expect(
        (await repository(errors: {'admin_invite_staff': Exception('offline')})
                .inviteStaff(
                  email: 'a@example.com',
                  fullName: 'A',
                  roleCode: 'cashier',
                ))
            .outcome,
        StaffInviteOutcome.failed,
      );
    },
  );

  test('the list keeps the status the database judged', () async {
    final invitations = await repository(
      responses: <String, Object?>{
        'admin_staff_invitations': <Map<String, dynamic>>[
          {
            'id': 'inv-1',
            'email': 'chef@example.com',
            'full_name': 'Chef One',
            'role_code': 'manager',
            'role_name_ar': 'مدير',
            'role_name_en': 'Manager',
            'branch_id': 'branch-1',
            'branch_name_ar': 'الرئيسي',
            'branch_name_en': 'Main',
            'status': 'pending',
            'expires_at': '2026-11-02T10:00:00Z',
            'invited_by_name': 'Owner One',
            'token': token,
          },
          {
            'id': 'inv-2',
            'email': 'old@example.com',
            'full_name': 'Pending No More',
            'role_code': 'cashier',
            'role_name_ar': 'كاشير',
            'role_name_en': 'Cashier',
            'status': 'expired',
            'token': null,
          },
        ],
      },
    ).loadInvitations();

    expect(invitations, hasLength(2));
    expect(invitations.first.isPending, isTrue);
    expect(invitations.first.canShareCode, isTrue);
    expect(invitations.first.roleName(), 'Manager');
    expect(invitations.first.branchName('Any branch'), 'Main');
    expect(invitations.first.expiresAt, DateTime.parse('2026-11-02T10:00:00Z'));
    expect(invitations.first.invitedByName, 'Owner One');
    // الحالة من القاعدة لا من ساعة الجهاز: صف تجاوز أجله يصل `expired`.
    expect(invitations.last.status, 'expired');
    expect(invitations.last.isPending, isFalse);
    expect(invitations.last.canShareCode, isFalse);
    // بلا فرع تُعرض الكلمة التي تقول «على مستوى المنصة»، لا فراغ.
    expect(invitations.last.branchName('All branches'), 'All branches');
  });

  test(
    'the options a caller may offer come as the function answers them',
    () async {
      final options = await repository(
        responses: <String, Object?>{
          'admin_staff_invite_options': <String, dynamic>{
            'ok': true,
            'roles': <Map<String, dynamic>>[
              {'code': 'manager', 'name_ar': 'مدير', 'name_en': 'Manager'},
            ],
            'branches': <Map<String, dynamic>>[
              {'id': 'branch-1', 'name_ar': 'الرئيسي', 'name_en': 'Main'},
            ],
            'can_offer_any_branch': true,
          },
        },
      ).loadInviteOptions();

      expect(options.roles.single.id, 'manager');
      expect(options.roles.single.name(), 'Manager');
      expect(options.branches.single.id, 'branch-1');
      expect(options.canOfferAnyBranch, isTrue);
    },
  );

  test(
    'an answer that is not the object the function promises is empty',
    () async {
      final options = await repository(
        responses: {'admin_staff_invite_options': null},
      ).loadInviteOptions();

      expect(options.roles, isEmpty);
      expect(options.branches, isEmpty);
      expect(options.canOfferAnyBranch, isFalse);
    },
  );

  test('withdrawing an invitation names only that row', () async {
    final client = StubSupabaseFunctions(
      responses: <String, Object?>{
        'admin_cancel_invitation': <String, dynamic>{'ok': true},
      },
    );

    expect(
      await AdminStaffRepository(client).cancelInvitation('inv-1'),
      StaffInviteOutcome.success,
    );
    expect(client.params['admin_cancel_invitation'], <String, dynamic>{
      'p_invitation_id': 'inv-1',
    });

    expect(
      await repository(
        responses: <String, Object?>{
          'admin_cancel_invitation': {'ok': false, 'reason': 'not_pending'},
        },
      ).cancelInvitation('inv-2'),
      StaffInviteOutcome.notPending,
    );

    expect(
      await repository(errors: {'admin_cancel_invitation': _denied()})
          .cancelInvitation('inv-3'),
      StaffInviteOutcome.permissionDenied,
    );
  });
}
