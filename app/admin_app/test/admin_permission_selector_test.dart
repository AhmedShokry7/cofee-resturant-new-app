import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/shared/widgets/admin_permission_selector.dart';

const _catalog = <Map<String, dynamic>>[
  {
    'code': 'orders.read',
    'name_ar': 'قراءة الطلبات',
    'name_en': 'Read orders',
    'description': 'View orders',
    'can_grant': true,
  },
  {
    'code': 'orders.cancel',
    'name_ar': 'إلغاء الطلبات',
    'name_en': 'Cancel orders',
    'description': 'Cancel orders',
    'can_grant': true,
  },
  {
    'code': 'orders.refund',
    'name_ar': 'استرداد الطلبات',
    'name_en': 'Refund orders',
    'description': 'Owner only',
    'can_grant': false,
    'can_revoke': false,
  },
];

Future<void> _pumpSelector(
  WidgetTester tester,
  Set<String> selected,
  ValueChanged<Set<String>> onChanged,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          body: SizedBox(
            height: 600,
            child: AdminPermissionSelector(
              catalog: _catalog,
              selected: selected,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('select all adds only grantable permissions', (tester) async {
    var selected = <String>{'orders.read'};
    await _pumpSelector(tester, selected, (next) => selected = next);

    expect(find.text(S.permissionsSelectedCount(1)), findsOneWidget);
    final checkboxes = tester
        .widgetList<Checkbox>(find.byType(Checkbox))
        .toList();
    expect(checkboxes, hasLength(3));
    expect(checkboxes[2].value, isFalse);
    expect(checkboxes[2].onChanged, isNull);

    await tester.tap(find.text(S.permissionsSelectAll));
    await tester.pump();

    expect(selected, {'orders.read', 'orders.cancel'});
    expect(selected, isNot(contains('orders.refund')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping one checkbox toggles it once', (tester) async {
    var selected = <String>{'orders.read'};
    await _pumpSelector(tester, selected, (next) => selected = next);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();

    expect(selected, {'orders.read', 'orders.cancel'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('clear all removes every selected permission in the group', (
    tester,
  ) async {
    var selected = <String>{'orders.read', 'orders.cancel'};
    await _pumpSelector(tester, selected, (next) => selected = next);

    await tester.tap(find.text(S.permissionsClearAll));
    await tester.pump();

    expect(selected, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an owner-only permission is locked from both sides', (
    tester,
  ) async {
    var selected = <String>{'orders.refund'};
    await _pumpSelector(tester, selected, (next) => selected = next);

    final locked = tester.widget<Checkbox>(find.byType(Checkbox).at(2));
    expect(locked.value, isTrue);
    expect(locked.onChanged, isNull);
    expect(find.byTooltip(S.permissionsOwnerOnly), findsOneWidget);

    final clear = tester.widget<TextButton>(
      find.widgetWithText(TextButton, S.permissionsClearAll),
    );
    expect(clear.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
