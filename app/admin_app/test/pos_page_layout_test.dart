import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/pos/domain/entities/pos_cart.dart';
import 'package:admin_app/features/pos/domain/entities/pos_catalog.dart';
import 'package:admin_app/features/pos/domain/entities/pos_customer.dart';
import 'package:admin_app/features/pos/domain/entities/pos_shift.dart';
import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_state.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_page_body.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_product_card.dart';
import 'package:admin_app/core/models/dining_table.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';

const _branches = <PosBranch>[
  PosBranch(id: 'b1', code: 'MAADI', nameAr: 'المعادي', nameEn: 'Maadi'),
  PosBranch(id: 'b2', code: 'NASR', nameAr: 'مدينة نصر', nameEn: 'Nasr City'),
];

const _categories = <PosCategory>[
  PosCategory(
    id: 'coffee',
    nameAr: 'قهوة',
    nameEn: 'Coffee',
    productCount: 2,
    sortOrder: 1,
  ),
  PosCategory(
    id: 'special',
    nameAr: 'عروض',
    nameEn: 'Specials',
    productCount: 1,
    sortOrder: 2,
  ),
];

const _payments = <PosPaymentMethod>[
  PosPaymentMethod(
    id: 'pay-cash',
    code: 'cash',
    nameAr: 'نقدي',
    nameEn: 'Cash',
    sortOrder: 1,
  ),
  PosPaymentMethod(
    id: 'pay-card',
    code: 'card',
    nameAr: 'بطاقة',
    nameEn: 'Card',
    sortOrder: 2,
  ),
];

const _products = <PosProduct>[
  PosProduct(
    id: 'p-latte',
    categoryId: 'coffee',
    nameAr: 'لاتيه',
    nameEn: 'Latte',
    categoryNameAr: 'قهوة',
    categoryNameEn: 'Coffee',
    unitPrice: 20,
    prepMinutes: 4,
    trackStock: true,
    stockQuantity: 5,
  ),
  PosProduct(
    id: 'p-tea',
    categoryId: 'coffee',
    nameAr: 'شاي',
    nameEn: 'Tea',
    categoryNameAr: 'قهوة',
    categoryNameEn: 'Coffee',
    unitPrice: 10,
  ),
  PosProduct(
    id: 'p-mocha',
    categoryId: 'special',
    nameAr: 'موكا',
    nameEn: 'Mocha',
    categoryNameAr: 'عروض',
    categoryNameEn: 'Specials',
    unitPrice: 30,
    regularPrice: 36,
    prepMinutes: 6,
    isFeatured: true,
  ),
];

const _customer = PosCustomer(
  id: 'c-walk',
  fullName: 'منى علي',
  phone: '01000000000',
  ordersCount: 3,
);

const _tables = <DiningTable>[
  DiningTable(id: 't-1', branchId: 'b1', name: 'طاولة 7', capacity: 4),
];

PosState _state({
  bool withCart = false,
  bool withCustomer = false,
  DiningTable? table,
  List<DiningTable> tables = _tables,
  PosTablesFailure? tablesFailure,
  bool withTax = false,
  PosShift? shift,
  bool shiftKnown = false,
}) {
  const latte = PosProduct(
    id: 'p-latte',
    nameAr: 'لاتيه',
    nameEn: 'Latte',
    unitPrice: 20,
  );
  const mocha = PosProduct(
    id: 'p-mocha',
    nameAr: 'موكا',
    nameEn: 'Mocha',
    unitPrice: 30,
  );

  return PosState(
    status: PosStatus.ready,
    branchId: 'b1',
    branches: _branches,
    categories: _categories,
    paymentMethods: _payments,
    products: _products,
    currencyCode: 'SAR',
    taxRate: withTax ? 15 : 0,
    taxIncluded: false,
    customer: withCustomer ? _customer : null,
    tables: tables,
    selectedTableId: table?.id,
    tablesFailure: tablesFailure,
    shift: shift,
    shiftKnown: shiftKnown,
    cart: withCart
        ? <PosCartLine>[
            PosCartLine(product: latte, quantity: 2),
            PosCartLine(product: mocha),
          ]
        : const <PosCartLine>[],
  );
}

void _setViewport(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(
  WidgetTester tester,
  PosState state, {
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
  VoidCallback? onOpenCart,
  VoidCallback? onChooseCustomer,
  VoidCallback? onShiftPressed,
}) async {
  final search = TextEditingController();
  addTearDown(search.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(
        body: PosPageBody(
          state: state,
          searchController: search,
          onSearchChanged: (_) {},
          onCategoryChanged: (_) {},
          onClearFilters: () {},
          onRefresh: () {},
          onBranchChanged: (_) {},
          onAddProduct: (_) {},
          onIncrement: (_) {},
          onDecrement: (_) {},
          onRemoveLine: (_) {},
          onClearCart: () {},
          onChooseCustomer: onChooseCustomer ?? () {},
          onClearCustomer: () {},
          onChooseTable: () {},
          onClearTable: () {},
          onRefreshTables: () {},
          onNoteChanged: (_) {},
          onPaymentModeChanged: (_) {},
          onSplitCashChanged: (_) {},
          onSplitCardChanged: (_) {},
          onCheckout: () {},
          onOpenCart: onOpenCart ?? () {},
          onShiftPressed: onShiftPressed ?? () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void _expectNoException(WidgetTester tester) {
  final exception = tester.takeException();
  if (exception is FlutterError) {
    fail(exception.toStringDeep());
  }
  expect(exception, isNull);
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the wide counter shows the customer, table and kitchen flow', (
    tester,
  ) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, 1500, 1100);

    await _pump(
      tester,
      _state(
        withCart: true,
        withCustomer: true,
        table: _tables.first,
        withTax: true,
      ),
      dark: true,
      direction: TextDirection.rtl,
    );

    _expectNoException(tester);
    expect(find.text(S.pos), findsOneWidget);
    expect(find.text(S.posSubtitle), findsOneWidget);
    expect(find.text('المعادي'), findsOneWidget);

    expect(find.text('قهوة'), findsWidgets);
    expect(find.text('عروض'), findsWidgets);
    expect(find.text('لاتيه'), findsWidgets);
    expect(find.text('موكا'), findsWidgets);

    expect(find.text(S.posCustomerChange), findsWidgets);
    expect(find.text('منى علي'), findsOneWidget);
    expect(find.text('01000000000'), findsOneWidget);
    expect(find.text(S.posCustomerWalkIn), findsWidgets);
    expect(find.text(S.posCustomerVip), findsNothing);

    expect(find.text(S.posDineIn), findsOneWidget);
    expect(find.text('طاولة 7'), findsOneWidget);
    expect(find.text(S.posChangeTable), findsWidgets);
    expect(find.byTooltip(S.posClearTable), findsOneWidget);
    expect(find.text(S.posTableSelectedHint), findsOneWidget);
    expect(find.text(S.posTableOptionalHint), findsNothing);
    expect(find.text(S.posPickup), findsNothing);
    expect(find.text(S.posPayCash), findsOneWidget);
    expect(find.text(S.posPayCard), findsOneWidget);
    expect(find.text(S.posPaySplit), findsOneWidget);
    expect(find.text(S.posSplitHint), findsNothing);
    expect(find.text(S.posPlaceOrder), findsOneWidget);
  });

  testWidgets('the header shows the live drawer and opens the shift panel', (
    tester,
  ) async {
    _setViewport(tester, 1500, 1100);
    var opened = 0;

    await _pump(
      tester,
      _state(
        withCart: true,
        shiftKnown: true,
        shift: PosShift(
          id: 's-1',
          branchId: 'b1',
          openingFloat: 120,
          cashSales: 40,
          cashIn: 10,
          cashOut: 5,
          expectedCash: 165,
          currencyCode: 'SAR',
          openedAt: DateTime(2026, 10, 26, 8, 5),
        ),
      ),
      onShiftPressed: () => opened += 1,
    );

    _expectNoException(tester);
    final button = find.byKey(const Key('pos-shift-button'));
    expect(button, findsOneWidget);
    expect(
      find.descendant(of: button, matching: find.text(S.posShiftActive)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: button, matching: find.textContaining('165.00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: button, matching: find.textContaining('08:05')),
      findsOneWidget,
    );

    await tester.tap(button);
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('without a drawer the header offers to open one', (tester) async {
    _setViewport(tester, 1500, 1100);
    var opened = 0;

    await _pump(
      tester,
      _state(withCart: true, shiftKnown: true),
      onShiftPressed: () => opened += 1,
    );

    _expectNoException(tester);
    final button = find.byKey(const Key('pos-shift-button'));
    expect(button, findsOneWidget);
    expect(
      find.descendant(of: button, matching: find.text(S.posShiftOpenAction)),
      findsOneWidget,
    );

    await tester.tap(button);
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('the split editor allows editing both cash and card amounts', (
    tester,
  ) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, 1500, 1100);

    final state = _state(
      withCart: true,
      withCustomer: true,
      table: _tables.first,
    ).copyWith(paymentMode: PosPaymentMode.split, splitCash: 5);

    await _pump(tester, state, direction: TextDirection.rtl);

    _expectNoException(tester);
    expect(find.text(S.posPayCash), findsOneWidget);
    expect(find.text(S.posPayCard), findsOneWidget);
    expect(find.text(S.posPaySplit), findsOneWidget);
    expect(find.text(S.posSplitCashLabel), findsOneWidget);
    expect(find.text(S.posSplitCardLabel), findsOneWidget);
    expect(find.text(S.posSplitHint), findsOneWidget);
    expect(find.byKey(const Key('pos-split-cash')), findsOneWidget);
    expect(find.byKey(const Key('pos-split-card')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('pos-split-cash')))
          .controller
          ?.text,
      localizeDigits('5'),
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('pos-split-card')))
          .controller
          ?.text,
      localizeDigits('65'),
    );
  });

  testWidgets(
    'the basket offers an optional table while the customer is empty',
    (tester) async {
      _setViewport(tester, 1500, 1100);

      await _pump(tester, _state(withCart: true));

      _expectNoException(tester);
      expect(find.text(S.posCustomerChoose), findsOneWidget);
      expect(find.text(S.posChooseTable), findsOneWidget);
      expect(find.text(S.posTableOptionalHint), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(S.posCustomerChoose)).dy,
        tester.getTopLeft(find.text(S.posChooseTable)).dy,
      );

      expect(find.text(S.posOptionalBadge), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('pos-checkout')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('the basket explains when the branch has no tables', (
    tester,
  ) async {
    _setViewport(tester, 1500, 1100);

    await _pump(tester, _state(withCart: true, tables: const []));

    _expectNoException(tester);
    expect(find.text(S.posNoTables), findsOneWidget);
    expect(find.text(S.posNoTablesHint), findsOneWidget);
  });

  testWidgets('a table load failure keeps the basket retryable', (
    tester,
  ) async {
    _setViewport(tester, 1500, 1100);

    await _pump(
      tester,
      _state(
        withCart: true,
        tables: const [],
        tablesFailure: PosTablesFailure.failed,
      ),
    );

    _expectNoException(tester);
    expect(find.text(S.posTablesLoadFailed), findsOneWidget);
    expect(find.text(S.retry), findsOneWidget);
  });

  testWidgets('a narrow counter keeps the catalog and opens the basket sheet', (
    tester,
  ) async {
    _setViewport(tester, 390, 844);
    var opened = false;

    await _pump(
      tester,
      _state(withCart: true, withCustomer: true),
      onOpenCart: () => opened = true,
    );

    _expectNoException(tester);
    expect(find.text(S.pos), findsOneWidget);
    expect(find.text('Coffee'), findsWidgets);
    expect(find.text('Latte'), findsWidgets);
    expect(find.text(S.posViewCart), findsOneWidget);
    expect(find.text(S.posCustomerChange), findsNothing);

    await tester.tap(find.text(S.posViewCart));
    await tester.pump();

    expect(opened, isTrue);
  });

  testWidgets('an empty narrow basket hides the floating bar', (tester) async {
    _setViewport(tester, 390, 844);

    await _pump(tester, _state());

    _expectNoException(tester);
    expect(find.text(S.posViewCart), findsNothing);
    expect(find.text('Latte'), findsWidgets);
  });

  testWidgets('the narrow toolbar exposes images, counts and categories', (
    tester,
  ) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, 390, 844);

    await _pump(tester, _state(), direction: TextDirection.rtl);

    _expectNoException(tester);
    expect(find.text(S.posAllCategories), findsOneWidget);
    expect(find.text(S.categoriesCount(2)), findsNothing);
    expect(find.text('قهوة'), findsWidgets);
    expect(find.text('عروض'), findsWidgets);

    await tester.drag(find.byType(ListView).first, const Offset(-200, 0));
    await tester.pump();

    _expectNoException(tester);
  });

  testWidgets('the category rail scrolls with the wheel and a mouse drag', (
    tester,
  ) async {
    _setViewport(tester, 390, 844);

    await _pump(tester, _state());

    final rail = find.byType(ListView).first;
    final controller = tester.widget<ListView>(rail).controller!;
    expect(controller.position.maxScrollExtent, greaterThan(0));
    expect(controller.offset, 0);

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(rail));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 30)));
    await tester.pump();

    expect(controller.offset, 30);
    final afterWheel = controller.offset;

    await tester.drag(
      rail,
      const Offset(-60, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();

    expect(controller.offset, greaterThan(afterWheel));
    _expectNoException(tester);
  });

  testWidgets('the product image fills the space the card leaves', (
    tester,
  ) async {
    _setViewport(tester, 1500, 1100);

    await _pump(tester, _state());

    final card = find.byType(PosProductCard).first;
    final thumb = find.descendant(
      of: card,
      matching: find.byType(AdminNetworkThumb),
    );
    expect(thumb, findsOneWidget);
    expect(tester.widget<AdminNetworkThumb>(thumb).fit, BoxFit.fill);

    final cardSize = tester.getSize(card);
    final imageSize = tester.getSize(thumb);
    expect(imageSize.width, cardSize.width);
    expect(imageSize.height, greaterThan(cardSize.height * .5));
    _expectNoException(tester);
  });

  testWidgets(
    'the basket shows hold order next to confirm order and calculates cash change',
    (tester) async {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      _setViewport(tester, 1500, 1100);

      final state = _state(withCart: true).copyWith(cashReceived: 100);

      await _pump(tester, state, direction: TextDirection.rtl);

      _expectNoException(tester);
      final holdButton = find.byKey(const Key('pos-hold-order'));
      final checkoutButton = find.byKey(const Key('pos-checkout'));
      expect(holdButton, findsOneWidget);
      expect(checkoutButton, findsOneWidget);
      expect(
        tester.getTopLeft(holdButton).dy,
        tester.getTopLeft(checkoutButton).dy,
      );

      expect(find.byKey(const Key('pos-cash-received')), findsOneWidget);
      expect(find.text(S.posCashChangeLabel), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('pos-cash-change-value')))
            .data,
        contains(localizeDigits('30.00')),
      );
    },
  );

  testWidgets('held orders appear in the empty cart and can be resumed', (
    tester,
  ) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, 1500, 1100);

    final held = PosHeldOrder(
      id: 'hold-1',
      number: 1,
      heldAt: DateTime(2026, 10, 28, 12, 30),
      cart: <PosCartLine>[PosCartLine(product: _products.first, quantity: 2)],
      customer: _customer,
      tableId: 't-1',
      tableName: 'طاولة 7',
    );
    final state = _state().copyWith(heldOrders: <PosHeldOrder>[held]);

    await _pump(tester, state, direction: TextDirection.rtl);

    _expectNoException(tester);
    expect(find.byKey(const Key('pos-held-orders-button')), findsOneWidget);
    expect(find.byKey(const Key('pos-held-order-1')), findsOneWidget);
    expect(find.byKey(const Key('pos-resume-held-1')), findsOneWidget);
  });
}
