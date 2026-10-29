import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/domain/entities/staff_invite_outcome.dart';
import 'package:admin_app/features/staff/presentation/manager/admin_staff_cubit.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_code_block.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_format.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_invitations_dialog.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';

import 'helpers/fake_staff_repository.dart';

const _token = '3f6a2b1e-8c4d-4e5f-9a0b-1c2d3e4f5a6b';

AdminStaffInvitation _invitation({
  String id = 'inv-1',
  String name = 'Chef One',
  String status = 'pending',
  String? token = _token,
  bool withBranch = true,
}) => AdminStaffInvitation(
  id: id,
  email: '$id@example.com',
  fullName: name,
  roleCode: 'manager',
  roleNameAr: 'مدير',
  roleNameEn: 'Manager',
  branchId: withBranch ? 'branch-1' : null,
  branchNameAr: withBranch ? 'الرئيسي' : null,
  branchNameEn: withBranch ? 'Main' : null,
  status: status,
  expiresAt: DateTime(2026, 11, 2),
  invitedByName: 'Owner One',
  token: token,
);

class _Opened {
  _Opened(this.repository, this.cubit);

  final FakeStaffRepository repository;
  final AdminStaffCubit cubit;

  bool? answer;
}

Future<_Opened> _open(
  WidgetTester tester, {
  List<AdminStaffInvitation> invitations = const [],
  bool canManage = true,
  StaffInviteOutcome cancelOutcome = StaffInviteOutcome.success,
  Object? readError,
}) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repository = FakeStaffRepository(
    invitations: invitations,
    cancelOutcome: cancelOutcome,
  )..invitationsError = readError;
  final cubit = AdminStaffCubit(repository: repository);
  final opened = _Opened(repository, cubit);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                opened.answer = await showStaffInvitationsDialog(
                  context: context,
                  cubit: cubit,
                  canManage: canManage,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  addTearDown(cubit.close);
  return opened;
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('every row says what the database said about it', (tester) async {
    await _open(
      tester,
      invitations: [
        _invitation(),
        _invitation(
          id: 'inv-2',
          name: 'Accepted Two',
          status: 'accepted',
          token: null,
          withBranch: false,
        ),
      ],
    );

    expect(find.text(S.staffInvitations), findsOneWidget);
    expect(find.text('Chef One'), findsOneWidget);
    expect(find.text('inv-1@example.com'), findsOneWidget);
    expect(find.text('Manager · Main'), findsOneWidget);
    // بلا فرع تُعرض الكلمة التي تقول «على مستوى المنصة»، لا فراغ.
    expect(find.text('Manager · ${S.staffInviteAllBranches}'), findsOneWidget);
    expect(
      find.text(StaffInvitationStatusView.of('pending').label),
      findsOneWidget,
    );
    expect(
      find.text(StaffInvitationStatusView.of('accepted').label),
      findsOneWidget,
    );
    // الرمز الذي حجبت القاعدة رؤيته لا تُخرعه الشاشة من مكان آخر.
    expect(find.byType(StaffCodeBlock), findsOneWidget);
    expect(find.text('Owner One'), findsWidgets);
  });

  testWidgets('a platform-wide invitation is named, not left blank', (
    tester,
  ) async {
    await _open(tester, invitations: [_invitation(withBranch: false)]);

    expect(find.text('Manager · ${S.staffInviteAllBranches}'), findsOneWidget);
  });

  testWidgets(
    'an account that manages nothing reads the list but withdraws none',
    (tester) async {
      await _open(tester, invitations: [_invitation()], canManage: false);

      expect(find.text('Chef One'), findsOneWidget);
      expect(find.text(S.staffInvitationCancel), findsNothing);
      // الرمز يصلها من القاعدة: القراءة وحدها لا تسحبه.
      expect(find.byType(StaffCodeBlock), findsOneWidget);
    },
  );

  testWidgets('a withdrawn invitation closes with the truth the page repeats', (
    tester,
  ) async {
    final opened = await _open(tester, invitations: [_invitation()]);
    final cancel = find.text(S.staffInvitationCancel);
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    expect(opened.repository.cancellations, ['inv-1']);
    // القراءة الأولى عند الفتح، وثانية بعد أن كتبته القاعدة.
    expect(opened.repository.invitationsReads, 2);
    expect(opened.answer, isTrue);
    expect(find.byType(StaffInvitationsDialog), findsNothing);
  });

  testWidgets('a row the database no longer allows to withdraw stays open', (
    tester,
  ) async {
    final opened = await _open(
      tester,
      invitations: [_invitation()],
      cancelOutcome: StaffInviteOutcome.notPending,
    );
    final cancel = find.text(S.staffInvitationCancel);
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    expect(find.text(S.staffInviteNotPending), findsOneWidget);
    expect(find.byType(StaffInvitationsDialog), findsOneWidget);
    expect(opened.repository.invitationsReads, 1);
    expect(opened.answer, isNull);
  });

  testWidgets('a failed read is a message, never an empty list', (
    tester,
  ) async {
    await _open(tester, readError: Exception('permission denied for function'));

    expect(find.text(S.staffNoInvitations), findsNothing);
    expect(find.byType(AdminInlineError), findsOneWidget);
  });

  testWidgets('a genuine empty list says so', (tester) async {
    await _open(tester);

    expect(find.text(S.staffNoInvitations), findsOneWidget);
    expect(find.byType(AdminInlineError), findsNothing);
  });
}
