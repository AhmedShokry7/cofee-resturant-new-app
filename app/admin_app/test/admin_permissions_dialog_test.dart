import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/locale/permission_catalog.dart';
import 'package:admin_app/shared/widgets/admin_permissions_dialog.dart';

const _catalog = <Map<String, dynamic>>[
  {'code': 'orders.read', 'name_ar': 'عرض الطلبات', 'name_en': 'View orders'},
  {
    'code': 'orders.cancel',
    'name_ar': 'إلغاء الطلبات',
    'name_en': 'Cancel orders',
  },
  {
    'code': 'payments.read',
    'name_ar': 'عرض المدفوعات',
    'name_en': 'View payments',
  },
];

Future<void> _openDialog(
  WidgetTester tester, {
  required bool canManage,
  required Future<void> Function(String code, bool granted) onToggle,
  List<Map<String, dynamic>> catalog = _catalog,
  String? emptyMessage,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAdminPermissionsDialog(
              context: context,
              title: 'Permissions for Manager',
              subtitle: 'manager',
              granted: const {'orders.read'},
              catalog: catalog,
              canManage: canManage,
              onToggle: onToggle,
              emptyMessage: emptyMessage,
            ),
            child: const Text('open'),
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
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('groups the catalogue and saves a toggle', (tester) async {
    final toggles = <(String, bool)>[];
    await _openDialog(
      tester,
      canManage: true,
      onToggle: (code, granted) async => toggles.add((code, granted)),
    );

    expect(find.text('Permissions for Manager'), findsOneWidget);
    expect(find.text('manager'), findsOneWidget);
    expect(find.text(permissionGroupName('orders')), findsOneWidget);
    expect(
      find.text(permissionName('orders.read', isArabic: false)),
      findsOneWidget,
    );
    expect(find.text(S.permissionsGrantedCount(1)), findsOneWidget);

    await tester.tap(
      find.text(permissionName('orders.cancel', isArabic: false)),
    );
    await tester.pumpAndSettle();

    expect(toggles, [('orders.cancel', true)]);
    expect(find.text(S.permissionsGrantedCount(2)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters the permissions by the search', (tester) async {
    await _openDialog(
      tester,
      canManage: true,
      onToggle: (code, granted) async {},
    );

    await tester.enterText(find.byType(TextField), 'payments');
    await tester.pumpAndSettle();

    expect(find.text(permissionGroupName('payments')), findsOneWidget);
    expect(
      find.text(permissionName('payments.read', isArabic: false)),
      findsOneWidget,
    );
    expect(
      find.text(permissionName('orders.read', isArabic: false)),
      findsNothing,
    );

    await tester.enterText(find.byType(TextField), 'nothing matches');
    await tester.pumpAndSettle();
    expect(find.text(S.permissionsNoMatches), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a read-only dialog disables every checkbox', (tester) async {
    final toggles = <(String, bool)>[];
    await _openDialog(
      tester,
      canManage: false,
      onToggle: (code, granted) async => toggles.add((code, granted)),
    );

    expect(find.text(S.permissionsReadOnly), findsOneWidget);
    final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(checkboxes, isNotEmpty);
    expect(checkboxes.every((checkbox) => checkbox.onChanged == null), isTrue);

    await tester.tap(
      find.text(permissionName('orders.cancel', isArabic: false)),
    );
    await tester.pumpAndSettle();

    expect(toggles, isEmpty);
    expect(find.text(S.permissionsGrantedCount(1)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the custom message for an empty read-only catalogue', (
    tester,
  ) async {
    await _openDialog(
      tester,
      canManage: false,
      onToggle: (code, granted) async {},
      catalog: const [],
      emptyMessage: S.roleNoPermissions,
    );

    expect(find.text(S.roleNoPermissions), findsOneWidget);
    expect(find.text(S.permissionsNoMatches), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
