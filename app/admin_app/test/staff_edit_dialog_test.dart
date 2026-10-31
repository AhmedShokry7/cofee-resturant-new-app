import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/domain/entities/staff_edit_outcome.dart';
import 'package:admin_app/features/staff/presentation/manager/admin_staff_cubit.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_edit_dialog.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_format.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';

import 'helpers/fake_staff_repository.dart';

AdminStaffMember _member({String status = 'active'}) => AdminStaffMember(
  id: 'staff-1',
  userId: 'user-1',
  fullName: 'Cashier One',
  email: 'cashier@example.com',
  status: status,
  createdAt: DateTime(2026, 3, 4),
  roles: const [AdminStaffRole(roleId: 'r1', roleCode: 'cashier')],
);

Future<void> _open(
  WidgetTester tester,
  AdminStaffCubit cubit,
  AdminStaffMember member, {
  Size size = const Size(1200, 1000),
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showStaffEditDialog(
                  context: context,
                  cubit: cubit,
                  member: member,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  Future<({AdminStaffCubit cubit, FakeStaffRepository repo})> ready(
    WidgetTester tester, {
    StaffEditOutcome outcome = StaffEditOutcome.success,
    Duration editDelay = Duration.zero,
    Size size = const Size(1200, 1000),
    TextDirection direction = TextDirection.ltr,
  }) async {
    final member = _member();
    final repo = FakeStaffRepository(
      members: [member],
      editOutcome: outcome,
      editDelay: editDelay,
    );
    final cubit = AdminStaffCubit(repository: repo);
    await cubit.load();
    await _open(tester, cubit, member, size: size, direction: direction);
    return (cubit: cubit, repo: repo);
  }

  testWidgets('a narrow Arabic phone fits the editor', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    await ready(
      tester,
      size: const Size(360, 720),
      direction: TextDirection.rtl,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(StaffEditDialog), findsOneWidget);
  });

  testWidgets('the editor wears the shared dialog chrome', (tester) async {
    await ready(tester);

    // الرأس والتذييل المشتركان: زر إغلاق، وشريط حفظ يوقف الزرين أثناء الكتابة.
    expect(find.byType(AdminDialogHeader), findsOneWidget);
    expect(find.byType(AdminDialogFooter), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AdminErrorBanner), findsNothing);
  });

  testWidgets('an address that is not an email stops before the database', (
    tester,
  ) async {
    final opened = await ready(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, S.email),
      'not-an-email',
    );
    await tester.tap(find.text(S.save));
    await tester.pumpAndSettle();

    expect(opened.repo.edits, isEmpty);
    expect(find.text(S.staffEditInvalidEmail), findsOneWidget);
    expect(find.byType(StaffEditDialog), findsOneWidget);
  });

  testWidgets('a save still running shows it and refuses a second one', (
    tester,
  ) async {
    final opened = await ready(tester, editDelay: const Duration(seconds: 1));
    await tester.enterText(
      find.widgetWithText(TextFormField, S.staffName),
      'Cashier Two',
    );
    await tester.tap(find.text(S.save));
    await tester.pump();

    // الزر يتحول إلى حالة الحفظ فلا يبقى شيء يُنقر مرتين.
    expect(find.text(S.saving), findsOneWidget);
    expect(find.text(S.save), findsNothing);

    await tester.pumpAndSettle();
    expect(opened.repo.edits, hasLength(1));
    expect(find.byType(StaffEditDialog), findsNothing);
  });

  testWidgets('the dialog opens on what the account holds', (tester) async {
    await ready(tester);

    expect(find.byType(StaffEditDialog), findsOneWidget);
    expect(find.text('Cashier One'), findsOneWidget);
    expect(find.text('cashier@example.com'), findsOneWidget);
    expect(find.text(StaffStatusView.of('active').label), findsOneWidget);
  });

  testWidgets('only the field the admin typed is written', (tester) async {
    final opened = await ready(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, S.staffName),
      'Cashier Two',
    );
    await tester.tap(find.text(S.save));
    await tester.pumpAndSettle();

    expect(opened.repo.edits, [
      {
        'staff': 'staff-1',
        'name': 'Cashier Two',
        'email': null,
        'status': null,
      },
    ]);
    expect(find.byType(StaffEditDialog), findsNothing);
  });

  testWidgets('a form nobody touched writes nothing', (tester) async {
    final opened = await ready(tester);
    await tester.tap(find.text(S.save));
    await tester.pumpAndSettle();

    // الصورة تُحفظ لحظة اختيارها، فالحفظ بلا تغيير لا يجب أن يستدعي القاعدة
    // ولا أن يعلن أن شيئًا حُفظ.
    expect(opened.repo.edits, isEmpty);
    expect(find.byType(StaffEditDialog), findsNothing);
  });

  testWidgets('the status picker sends the code, not the label', (
    tester,
  ) async {
    final opened = await ready(tester);
    await tester.tap(find.text(StaffStatusView.of('suspended').label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.save));
    await tester.pumpAndSettle();

    expect(opened.repo.edits.single['status'], 'suspended');
    expect(opened.repo.edits.single['name'], isNull);
  });

  testWidgets('a refusal keeps the dialog open and says why', (tester) async {
    await ready(tester, outcome: StaffEditOutcome.duplicateEmail);
    await tester.enterText(
      find.widgetWithText(TextFormField, S.email),
      'taken@example.com',
    );
    await tester.tap(find.text(S.save));
    await tester.pumpAndSettle();

    expect(find.text(S.staffEditDuplicateEmail), findsOneWidget);
    expect(find.byType(StaffEditDialog), findsOneWidget);
  });

  testWidgets('the picture of the row previews in the dialog', (tester) async {
    final member = _member();
    final repo = FakeStaffRepository(members: [member]);
    final cubit = AdminStaffCubit(repository: repo);
    await cubit.load();
    await _open(tester, cubit, member);

    await cubit.setStaffImage('staff-1', 'staff/staff-1/1.jpg');
    await cubit.load();

    expect(
      repo.members.single.avatarUrl,
      'https://signed/staff/staff-1/1.jpg?token=fresh',
    );
  });
}
