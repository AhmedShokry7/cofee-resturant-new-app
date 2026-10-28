import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/data/repositories/admin_order_repository.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/domain/entities/order_status_rules.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_cubit.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_cards.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_status_control.dart';

/// نفس ما يرجّعه `admin_order_status_matrix()` (ترحيلة 195) من القاعدة الحيّة.
const Map<Object?, Object?> _matrixJson = <Object?, Object?>{
  'can_cancel': true,
  'matrix': <String, Object?>{
    'pending': <String>['cancelled', 'confirmed'],
    'confirmed': <String>['cancelled', 'preparing'],
    'preparing': <String>['cancelled', 'ready'],
    'ready': <String>['completed', 'out_for_delivery', 'preparing'],
    'out_for_delivery': <String>['completed'],
  },
};

class _FakeOrderRepository extends AdminOrderRepository {
  OrderStatusRules? rules;
  Object? failure;
  int reads = 0;

  @override
  Future<OrderStatusRules?> loadStatusRules() async {
    reads += 1;
    if (failure != null) throw failure!;
    return rules;
  }
}

AdminOrder _order({String id = 'o1', String status = 'confirmed'}) =>
    AdminOrder(
      id: id,
      orderNumber: '1001',
      userId: 'c1',
      customerName: 'Ahmed',
      customerEmail: 'ahmed@example.com',
      branchNameAr: 'الفرع الرئيسي',
      branchNameEn: 'Main branch',
      fulfillmentType: 'delivery',
      status: status,
      paymentStatus: 'unpaid',
      subtotal: 20,
      discountTotal: 0,
      deliveryFee: 0,
      taxTotal: 0,
      grandTotal: 20,
      placedAt: DateTime(2026, 10, 20, 14, 30),
      items: const <AdminOrderItem>[],
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('OrderStatusRules', () {
    test('يقرأ المصفوفة وصلاحية الإلغاء من payload القاعدة', () {
      final rules = OrderStatusRules.fromJson(_matrixJson);
      expect(rules.canCancel, isTrue);
      expect(rules.allowedFor('pending'), <String>['cancelled', 'confirmed']);
      expect(rules.allowedFor('ready'), <String>[
        'completed',
        'out_for_delivery',
        'preparing',
      ]);
    });

    test('الحالة المغلقة قائمة فارغة، وليست قراءة غائبة', () {
      final rules = OrderStatusRules.fromJson(_matrixJson);
      expect(rules.allowedFor('completed'), isEmpty);
      expect(rules.allowedFor('cancelled'), isEmpty);
    });

    test('بدون orders.cancel لا يظهر الإلغاء في القائمة', () {
      final rules = OrderStatusRules.fromJson(_matrixJson);
      final noCancel = OrderStatusRules(canCancel: false, edges: rules.edges);
      expect(noCancel.allowedFor('pending'), <String>['confirmed']);
      expect(noCancel.allowedFor('ready'), <String>[
        'completed',
        'out_for_delivery',
        'preparing',
      ]);
    });

    test('payload غير مفهوم يتحوّل إلى مصفوفة فارغة بلا انهيار', () {
      final rules = OrderStatusRules.fromJson(<Object?, Object?>{
        'can_cancel': 'yes',
        'matrix': <String, Object?>{
          'pending': <Object?>[1, 'confirmed'],
        },
      });
      expect(rules.canCancel, isFalse);
      expect(rules.allowedFor('pending'), <String>['confirmed']);
    });
  });

  group('AdminOrderCubit.loadStatusRules', () {
    test('يخزّن المصفوفة ويقرأها مرة واحدة ولو طُلبت مرّتين', () async {
      final repository = _FakeOrderRepository()
        ..rules = OrderStatusRules.fromJson(_matrixJson);
      final cubit = AdminOrderCubit(repository: repository);

      await cubit.loadStatusRules();
      await cubit.loadStatusRules();

      expect(repository.reads, 1);
      expect(cubit.state.statusRules?.allowedFor('pending'), <String>[
        'cancelled',
        'confirmed',
      ]);
      cubit.close();
    });

    test('فشل القراءة يترك الحالة null فلا تتجمّد القوائم', () async {
      final repository = _FakeOrderRepository()..failure = StateError('down');
      final cubit = AdminOrderCubit(repository: repository);

      await cubit.loadStatusRules();

      expect(repository.reads, 1);
      expect(cubit.state.statusRules, isNull);
      cubit.close();
    });
  });

  group('قائمة الحالات في التفاصيل', () {
    testWidgets('يعرض الحالات التي تسمح بها المصفوفة فقط', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OrderDetailStatusControl(
            order: _order(),
            saving: false,
            allowedStatuses: const <String>['cancelled', 'preparing'],
            onChanged: (_) {},
          ),
        ),
      );
      final button = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(button.items!.map((item) => item.value), <String>[
        'cancelled',
        'preparing',
      ]);
    });

    testWidgets('يبدي كل الحالات قبل أن تُقرأ المصفوفة', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OrderDetailStatusControl(
            order: _order(),
            saving: false,
            onChanged: (_) {},
          ),
        ),
      );
      final button = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(button.items, hasLength(7));
    });

    testWidgets('الطلب المغلق يقول إنه لا حالة تالية، بلا قائمة', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OrderDetailStatusControl(
            order: _order(status: 'completed'),
            saving: false,
            allowedStatuses: const <String>[],
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text(S.orderStatusClosed), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });
  });

  group('قائمة الحالة السريعة في البطاقات', () {
    testWidgets('القائمة تقبل ما تسمح به المصفوفة', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OrderCard(
            order: _order(status: 'ready'),
            allowedStatuses: const <String>[
              'completed',
              'out_for_delivery',
              'preparing',
            ],
            onChangeStatus: (_) {},
          ),
        ),
      );
      final button = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      final context = tester.element(find.byType(PopupMenuButton<String>));
      final items = button.itemBuilder(context);
      expect(
        items.map((item) => (item as PopupMenuItem<String>).value),
        <String>['completed', 'out_for_delivery', 'preparing'],
      );
    });

    testWidgets('بطاقة الطلب المغلق بلا قائمة حالة', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OrderCard(
            order: _order(status: 'completed'),
            allowedStatuses: const <String>[],
            onChangeStatus: (_) {},
          ),
        ),
      );
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('بطاقة بدون صلاحية إلغاء لا تُدرجه', (tester) async {
      final repository = _FakeOrderRepository()
        ..rules = OrderStatusRules(
          canCancel: false,
          edges: OrderStatusRules.fromJson(_matrixJson).edges,
        );
      final cubit = AdminOrderCubit(repository: repository);
      await cubit.loadStatusRules();

      await tester.pumpWidget(
        _wrap(
          OrderCards(
            orders: <AdminOrder>[_order(status: 'pending')],
            canManage: true,
            statusRules: cubit.state.statusRules,
            onChangeStatus: (_, _) {},
            onOpen: (_) {},
          ),
        ),
      );
      final context = tester.element(find.byType(PopupMenuButton<String>));
      final button = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      final values = button
          .itemBuilder(context)
          .map((item) => (item as PopupMenuItem<String>).value)
          .toList();
      expect(values, <String>['confirmed']);
      cubit.close();
    });
  });
}
