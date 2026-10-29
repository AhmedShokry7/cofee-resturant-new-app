import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/domain/entities/staff_invite_outcome.dart';
import 'package:admin_app/features/staff/presentation/manager/admin_staff_cubit.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_code_block.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_invite_dialog.dart';

import 'helpers/fake_staff_repository.dart';

const _token = '3f6a2b1e-8c4d-4e5f-9a0b-1c2d3e4f5a6b';

AdminInviteOptions _options({bool anyBranch = false}) => AdminInviteOptions(
  roles: const [
    AdminInviteChoice(id: 'manager', nameAr: 'مدير', nameEn: 'Manager'),
  ],
  branches: const [
    AdminInviteChoice(id: 'branch-1', nameAr: 'الرئيسي', nameEn: 'Main'),
  ],
  canOfferAnyBranch: anyBranch,
);

/// يفتح النموذج على دليل مصطنع، ويرجع الدليل والقيمة التي أجاب بها الحوار.
///
/// القيمة هي ما تقرأه الصفحة لتقرر أن تقول «أُرسلت الدعوة» أو تصمت، فاختبارها
/// جزء من السلوك لا تفصيل داخلي.
class _Opened {
  _Opened(this.repository, this.cubit);

  final FakeStaffRepository repository;
  final AdminStaffCubit cubit;

  bool? answer;
}

Future<_Opened> _open(
  WidgetTester tester, {
  AdminInviteOptions? options,
  StaffInviteOutcome outcome = StaffInviteOutcome.success,
  String? code = _token,
}) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repository = FakeStaffRepository(
    options: options ?? _options(),
    inviteOutcome: outcome,
    inviteCode: code,
  );
  final cubit = AdminStaffCubit(repository: repository);
  final opened = _Opened(repository, cubit);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                opened.answer = await showStaffInviteDialog(
                  context: context,
                  cubit: cubit,
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

Future<void> _fillAndSend(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, S.staffInviteName),
    'Chef One',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, S.staffInviteEmail),
    'chef@example.com',
  );
  final send = find.text(S.staffInviteSend);
  await tester.ensureVisible(send);
  await tester.pumpAndSettle();
  await tester.tap(send);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the form waits for the list the database allowed', (
    tester,
  ) async {
    await _open(tester);

    expect(find.byType(StaffInviteDialog), findsOneWidget);
    expect(find.text(S.staffInviteTitle), findsOneWidget);
    // الدور والفرع من `admin_staff_invite_options`، لا من كتالوج كامل.
    expect(find.text('Manager'), findsOneWidget);
    expect(find.text('Main'), findsOneWidget);
    // لا اسم ولا بريد بعد، لكن الزرّ حيّ: التحقق يحدث عند الضغط ويشرح الناقص.
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, S.staffInviteSend),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('an unfinished form is refused before the database is asked', (
    tester,
  ) async {
    final opened = await _open(tester);
    final send = find.text(S.staffInviteSend);
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(find.text(S.staffEditInvalidName), findsOneWidget);
    expect(opened.repository.invites, isEmpty);
    expect(find.byType(StaffInviteDialog), findsOneWidget);
  });

  testWidgets('a form with a name but no real email stops at the email', (
    tester,
  ) async {
    final opened = await _open(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, S.staffInviteName),
      'Chef One',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, S.staffInviteEmail),
      'chef at example',
    );
    final send = find.text(S.staffInviteSend);
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(find.text(S.staffEditInvalidEmail), findsOneWidget);
    expect(opened.repository.invites, isEmpty);
  });

  testWidgets(
    'a sent invitation shows the code and the page says it was sent',
    (tester) async {
      final opened = await _open(tester);
      await _fillAndSend(tester);

      final block = tester.widget<StaffCodeBlock>(find.byType(StaffCodeBlock));
      expect(block.code, _token);
      expect(opened.repository.invites, [
        {
          'email': 'chef@example.com',
          'name': 'Chef One',
          'role': 'manager',
          'branch': 'branch-1',
        },
      ]);
      // الرمز لا يُقرأ من القائمة: قائمةٌ واحدة تعيد قراءتها الدالة بعد النجاح.
      expect(opened.repository.invitationsReads, 1);

      await tester.tap(find.text(S.close));
      await tester.pumpAndSettle();
      expect(find.byType(StaffInviteDialog), findsNothing);
      expect(opened.answer, isTrue);
    },
  );

  testWidgets('a refusal keeps the form open and says the database reason', (
    tester,
  ) async {
    await _open(tester, outcome: StaffInviteOutcome.alreadyInvited, code: null);
    await _fillAndSend(tester);

    expect(find.text(S.staffInviteAlreadyInvited), findsOneWidget);
    expect(find.byType(StaffCodeBlock), findsNothing);
    expect(find.byType(StaffInviteDialog), findsOneWidget);
  });

  testWidgets('a branch manager is never offered a platform-wide invitation', (
    tester,
  ) async {
    await _open(tester);

    // فرعُه مُختارٌ لأنه الوحيد في نطاقه، فلا «على مستوى المنصة» في قائمته.
    expect(find.text('Main'), findsOneWidget);
    expect(find.text(S.staffInviteAllBranches), findsNothing);
  });

  testWidgets(
    'the platform-wide option appears only for a caller who may grant it',
    (tester) async {
      await _open(tester, options: _options(anyBranch: true));

      expect(find.text(S.staffInviteAllBranches), findsOneWidget);
      await tester.tap(find.text(S.staffInviteAllBranches));
      await tester.pumpAndSettle();
      expect(find.text('Main'), findsOneWidget);
    },
  );

  testWidgets(
    'an account that may offer nothing is told so, not shown blanks',
    (tester) async {
      await _open(tester, options: const AdminInviteOptions());

      expect(find.text(S.staffInviteNoOptions), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    },
  );
}
