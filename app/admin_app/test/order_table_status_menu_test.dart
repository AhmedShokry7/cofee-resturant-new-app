import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/order_status.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/domain/entities/order_status_rules.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_cards.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_directory.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filter_values.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_table_row.dart';

AdminOrder _order({String status = 'preparing'}) => AdminOrder(
  id: 'o1',
  orderNumber: '2001',
  customerName: 'Customer',
  fulfillmentType: 'delivery',
  status: status,
  paymentStatus: 'paid',
  subtotal: 20,
  discountTotal: 0,
  deliveryFee: 0,
  taxTotal: 0,
  grandTotal: 20,
);

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required List<AdminOrder> orders,
  required bool canManage,
  OrderStatusRules? statusRules,
  void Function(AdminOrder order, String status)? onChangeStatus,
  bool dark = false,
  bool rtl = false,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final directory = OrderDirectory(
    orders: orders,
    branches: const [],
    search: '',
    onSearchChanged: (_) {},
    filters: const OrderFilterValues(),
    onFiltersChanged: (_) {},
    canManage: canManage,
    statusRules: statusRules,
    onChangeStatus: onChangeStatus ?? (_, _) {},
    onOpen: (_) {},
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      home: Scaffold(
        body: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: directory,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// قوائم الحالة داخل صفوف الجدول وحده، فتصفية الأدوات لا تعدّ رأس الجدول.
Finder _tableMenus() => find.descendant(
  of: find.byType(OrderTableRow),
  matching: find.byType(PopupMenuButton<String>),
);

Finder _cardMenus() => find.descendant(
  of: find.byType(OrderCard),
  matching: find.byType(PopupMenuButton<String>),
);

Future<List<String?>> _openFirstMenu(WidgetTester tester, Finder menus) async {
  await tester.tap(menus.first);
  await tester.pumpAndSettle();
  final values = tester
      .widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
      .map((item) => item.value)
      .toList(growable: false);
  // القائمة المفتوحة تحجب ما بعدها، فكل قياسٍ بعدها يحتاج إغلاقها أولًا.
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  return values;
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the wide table gives a manager the status menu', (tester) async {
    await _pump(
      tester,
      width: 1400,
      orders: [_order()],
      canManage: true,
      statusRules: const OrderStatusRules(
        canCancel: false,
        edges: {
          'preparing': ['ready', 'cancelled'],
        },
      ),
    );

    expect(_tableMenus(), findsOneWidget);
    // بلا صلاحية الإلغاء لا تُعرض حافّته، كما تفعل البطاقة تمامًا.
    expect(await _openFirstMenu(tester, _tableMenus()), ['ready']);
  });

  testWidgets('a read-only role sees no status menu in the wide table', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 1400,
      orders: [_order()],
      canManage: false,
      statusRules: const OrderStatusRules(
        canCancel: true,
        edges: {
          'preparing': ['ready'],
        },
      ),
    );

    expect(_tableMenus(), findsNothing);
    expect(find.text('#2001'), findsOneWidget);
  });

  testWidgets('a closed order prints no menu in the wide table', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 1400,
      orders: [_order(status: 'completed')],
      canManage: true,
      statusRules: const OrderStatusRules(canCancel: true, edges: {}),
    );

    expect(_tableMenus(), findsNothing);
  });

  testWidgets('choosing a status in the table reports that order and edge', (
    tester,
  ) async {
    final chosen = <(String, String)>[];
    await _pump(
      tester,
      width: 1400,
      orders: [_order()],
      canManage: true,
      statusRules: const OrderStatusRules(
        canCancel: true,
        edges: {
          'preparing': ['ready'],
        },
      ),
      onChangeStatus: (order, status) => chosen.add((order.id, status)),
    );

    await tester.tap(_tableMenus().first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, S.statusReady));
    await tester.pumpAndSettle();

    expect(chosen, [('o1', 'ready')]);
  });

  testWidgets('the table offers what the cards offer before the read', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 700,
      orders: [_order()],
      canManage: true,
      statusRules: null,
    );
    final cards = await _openFirstMenu(tester, _cardMenus());
    expect(cards, OrderStatusView.allCodes);

    await _pump(
      tester,
      width: 1400,
      orders: [_order()],
      canManage: true,
      statusRules: null,
    );
    final table = await _openFirstMenu(tester, _tableMenus());

    // الشاشة الضيقة والعريضة سؤالٌ واحد للقاعدة: لا تُمنح إحداهما حافةً تردّ
    // الأخرى عليها.
    expect(table, cards);
  });

  testWidgets('العربية والوضع الليلي في أضيق جدول بلا طفرة', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    await _pump(
      tester,
      width: 900,
      orders: [
        _order(),
        _order(status: 'pending'),
      ],
      canManage: true,
      statusRules: const OrderStatusRules(
        canCancel: true,
        edges: {
          'preparing': ['ready', 'cancelled'],
          'pending': ['confirmed'],
        },
      ),
      dark: true,
      rtl: true,
    );

    // الخانة نفسها الآن تحمل الحالة والقائمة معًا، فاختبارها عند حدّها: أقل
    // عرضٍ يمرّ في الجدول وأطول تسميتين في العربية.
    expect(tester.takeException(), isNull);
    expect(_tableMenus(), findsNWidgets(2));
  });
}
