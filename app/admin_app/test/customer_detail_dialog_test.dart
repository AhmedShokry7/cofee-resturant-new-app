import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/customers/data/models/admin_customer.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_detail_dialog.dart';

Map<String, dynamic> _order(int index) => <String, dynamic>{
  'status': 'completed',
  'fulfillment_type': 'delivery',
  'grand_total': 40,
  'placed_at': '2026-09-01T10:00:00Z',
  'branch_name_ar': 'الفرع الرئيسي',
  'branch_name_en': 'Main branch',
  'items': <Map<String, dynamic>>[
    {'product_name_ar': 'قهوة', 'product_name_en': 'Coffee', 'quantity': 2},
  ],
};

Map<String, dynamic> _details({int orderCount = 6}) => <String, dynamic>{
  'profile': <String, dynamic>{
    'email': 'sara@example.com',
    'phone': '+966500000000',
    'created_at': '2026-01-15T08:00:00Z',
    'admin_notes': 'Prefers morning delivery',
    'is_vip': false,
    'is_blacklisted': false,
  },
  'addresses': <dynamic>[
    {'label': 'Home', 'details': 'Riyadh, Olaya district', 'is_default': true},
  ],
  'orders': <dynamic>[
    for (var index = 0; index < orderCount; index++) _order(index),
  ],
  'subscriptions': <dynamic>[],
};

const _customer = AdminCustomer(
  id: 'c1',
  fullName: 'Sara Ali',
  email: 'sara@example.com',
  phone: '+966500000000',
  createdAt: null,
  ordersCount: 6,
  totalSpent: 240,
);

Future<void> _openDialog(
  WidgetTester tester, {
  required Widget dialog,
  required Size size,
  required bool dark,
  required bool isArabic,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  AppLocale.instance.debugSet(
    isArabic ? AppLanguage.arabic : AppLanguage.english,
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  showDialog<void>(context: context, builder: (_) => dialog),
              child: const Text('open'),
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
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the detail dialog scrolls instead of overflowing', (
    tester,
  ) async {
    await _openDialog(
      tester,
      dialog: CustomerDetailDialog(
        customer: _customer,
        details: _details(),
        onSave: ({
          required bool isVip,
          required bool isBlacklisted,
          required String adminNotes,
        }) async {},
      ),
      size: const Size(360, 640),
      dark: false,
      isArabic: false,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Sara Ali'), findsOneWidget);
    expect(find.text('sara@example.com'), findsOneWidget);
    expect(find.textContaining('Coffee'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Riyadh, Olaya district'), findsOneWidget);
    expect(find.text('Prefers morning delivery'), findsOneWidget);
  });

  testWidgets('the customer dialog lists the subscriptions payload', (
    tester,
  ) async {
    await _openDialog(
      tester,
      dialog: CustomerDetailDialog(
        customer: _customer,
        details: <String, dynamic>{
          'profile': <String, dynamic>{'email': _customer.email},
          'addresses': <dynamic>[],
          'orders': <dynamic>[],
          'subscriptions': <dynamic>[
            <String, dynamic>{
              'status': 'active',
              'starts_at': '2026-09-01T08:00:00Z',
              'ends_at': '2026-10-01T08:00:00Z',
              'cups_entitled': 20,
              'cups_used': 5,
              'cups_carried_over': 2,
              'plan': <String, dynamic>{
                'name_ar': 'الذهبية',
                'name_en': 'Gold plan',
              },
            },
          ],
        },
        onSave: _noopSave,
      ),
      size: const Size(900, 900),
      dark: false,
      isArabic: false,
    );

    expect(find.text(S.customerSubscriptionsLabel), findsOneWidget);
    expect(find.text('Gold plan'), findsOneWidget);
    expect(find.text(S.activeStatus), findsOneWidget);
    expect(find.textContaining('5 / 22'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the detail dialog fits a very narrow Arabic dark screen', (
    tester,
  ) async {
    await _openDialog(
      tester,
      dialog: const CustomerDetailDialog(
        customer: AdminCustomer(
          id: 'c2',
          fullName: 'سارة علي',
          ordersCount: 6,
          totalSpent: 240,
        ),
        details: <String, dynamic>{
          'profile': <String, dynamic>{},
          'addresses': <dynamic>[],
          'orders': <dynamic>[],
          'subscriptions': <dynamic>[],
        },
        onSave: _noopSave,
      ),
      size: const Size(320, 640),
      dark: true,
      isArabic: true,
      direction: TextDirection.rtl,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('سارة علي'), findsOneWidget);
    expect(find.text('حفظ'), findsOneWidget);
  });

  testWidgets('saving returns the edited flags and notes', (tester) async {
    bool? savedVip;
    bool? savedBlacklist;
    String? savedNotes;
    await _openDialog(
      tester,
      dialog: CustomerDetailDialog(
        customer: _customer,
        details: _details(orderCount: 1),
        onSave:
            ({
              required bool isVip,
              required bool isBlacklisted,
              required String adminNotes,
            }) async {
              savedVip = isVip;
              savedBlacklist = isBlacklisted;
              savedNotes = adminNotes;
            },
      ),
      size: const Size(900, 900),
      dark: false,
      isArabic: false,
    );

    await tester.enterText(find.byType(TextField), 'Call before delivery');
    await tester.tap(find.text('VIP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedVip, isTrue);
    expect(savedBlacklist, isFalse);
    expect(savedNotes, 'Call before delivery');
    expect(find.byType(CustomerDetailDialog), findsNothing);
  });
}

Future<void> _noopSave({
  required bool isVip,
  required bool isBlacklisted,
  required String adminNotes,
}) async {}
