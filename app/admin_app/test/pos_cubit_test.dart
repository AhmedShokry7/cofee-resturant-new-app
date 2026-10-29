import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/pos/domain/entities/pos_catalog.dart';
import 'package:admin_app/features/pos/domain/entities/pos_cashier.dart';
import 'package:admin_app/features/pos/domain/entities/pos_customer.dart';
import 'package:admin_app/features/pos/domain/entities/pos_order_result.dart';
import 'package:admin_app/features/pos/domain/entities/pos_shift.dart';
import 'package:admin_app/features/pos/domain/entities/pos_table.dart';
import 'package:admin_app/features/pos/data/repositories/admin_pos_repository.dart';
import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_cubit.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_state.dart';
import 'package:admin_app/core/models/dining_enums.dart';
import 'package:admin_app/core/models/dining_reservation.dart';
import 'package:admin_app/core/models/dining_table.dart';

const _branches = <PosBranch>[
  PosBranch(id: 'b1', code: 'MAADI', nameAr: 'المعادي', nameEn: 'Maadi'),
  PosBranch(id: 'b2', code: 'NASR', nameAr: 'مدينة نصر', nameEn: 'Nasr City'),
];

const _categories = <PosCategory>[
  PosCategory(id: 'coffee', nameAr: 'قهوة', nameEn: 'Coffee'),
  PosCategory(id: 'special', nameAr: 'عروض', nameEn: 'Specials'),
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

const _mochaGroups = <PosOptionGroup>[
  PosOptionGroup(
    id: 'g-size',
    nameAr: 'الحجم',
    nameEn: 'Size',
    selectionType: PosSelectionType.single,
    isRequired: true,
    values: [
      PosOptionValue(id: 'v-small', nameAr: 'صغير', nameEn: 'Small'),
      PosOptionValue(
        id: 'v-large',
        nameAr: 'كبير',
        nameEn: 'Large',
        priceDelta: 5,
      ),
    ],
  ),
  PosOptionGroup(
    id: 'g-extras',
    nameAr: 'إضافات',
    nameEn: 'Extras',
    selectionType: PosSelectionType.multiple,
    maxSelect: 2,
    values: [
      PosOptionValue(
        id: 'v-oat',
        nameAr: 'شوفان',
        nameEn: 'Oat milk',
        priceDelta: 2,
      ),
      PosOptionValue(
        id: 'v-shot',
        nameAr: 'شوت',
        nameEn: 'Extra shot',
        priceDelta: 3,
      ),
      PosOptionValue(
        id: 'v-vanilla',
        nameAr: 'فانيليا',
        nameEn: 'Vanilla',
        priceDelta: 1,
      ),
    ],
  ),
];

PosProduct _latte({int stock = 5, bool available = true}) => PosProduct(
  id: 'p-latte',
  categoryId: 'coffee',
  sku: 'LAT-01',
  nameAr: 'لاتيه',
  nameEn: 'Latte',
  unitPrice: 20,
  stockQuantity: stock,
  trackStock: true,
  isAvailable: available,
);

const _tea = PosProduct(
  id: 'p-tea',
  categoryId: 'coffee',
  sku: 'TEA-01',
  nameAr: 'شاي',
  nameEn: 'Tea',
  unitPrice: 10,
);

PosProduct _mocha({List<PosOptionGroup>? groups}) => PosProduct(
  id: 'p-mocha',
  categoryId: 'special',
  sku: 'MOC-01',
  nameAr: 'موكا',
  nameEn: 'Mocha',
  unitPrice: 30,
  optionGroups: groups ?? _mochaGroups,
);

PosCatalog _catalog({
  String branchId = 'b1',
  bool taxIncluded = false,
  List<PosProduct>? products,
  List<PosCategory> categories = _categories,
  List<PosPaymentMethod> payments = _payments,
}) {
  return PosCatalog(
    branchId: branchId,
    currencyCode: 'SAR',
    taxRate: 15,
    taxIncluded: taxIncluded,
    branches: _branches,
    categories: categories,
    paymentMethods: payments,
    products: products ?? <PosProduct>[_latte(), _tea, _mocha()],
  );
}

DiningTable _table({
  String id = 't-1',
  String name = 'طاولة 1',
  String branchId = 'b1',
  DiningArea area = DiningArea.hall,
  int capacity = 4,
  DiningTableStatus status = DiningTableStatus.available,
  DiningActiveOrder? activeOrder,
  DiningReservation? reservation,
}) => DiningTable(
  id: id,
  branchId: branchId,
  name: name,
  area: area,
  capacity: capacity,
  status: status,
  activeOrder: activeOrder,
  reservation: reservation,
);

DiningReservation _reservation({
  String id = 'r-1',
  String tableId = 't-3',
  DiningReservationStatus status = DiningReservationStatus.confirmed,
  String customerName = 'سارة',
}) => DiningReservation(
  id: id,
  branchId: 'b1',
  tableId: tableId,
  customerName: customerName,
  partySize: 2,
  reservedFor: DateTime.now().add(const Duration(minutes: 30)),
  status: status,
);

List<DiningTable> _floor() => <DiningTable>[
  _table(id: 't-1', name: 'طاولة 1'),
  _table(id: 't-2', name: 'طاولة 2', area: DiningArea.terrace, capacity: 2),
];

PosShift _openShift({
  String id = 's-1',
  String branchId = 'b1',
  double openingFloat = 100,
  double cashSales = 0,
  double cardSales = 0,
  double cashIn = 0,
  double cashOut = 0,
  int orderCount = 0,
  DateTime? openedAt,
}) {
  return PosShift(
    id: id,
    branchId: branchId,
    openingFloat: openingFloat,
    cashSales: cashSales,
    cardSales: cardSales,
    salesTotal: cashSales + cardSales,
    orderCount: orderCount,
    cashIn: cashIn,
    cashOut: cashOut,
    expectedCash: openingFloat + cashSales + cashIn - cashOut,
    currencyCode: 'SAR',
    openedByName: 'منى علي',
    openedAt: openedAt ?? DateTime(2026, 10, 26, 8, 5),
  );
}

PosShift _closedShift({
  String id = 's-closed',
  double openingFloat = 100,
  double cashSales = 40,
  double cardSales = 20,
  double cashIn = 10,
  double cashOut = 5,
  int orderCount = 3,
  double countedCash = 145,
  String closeNote = '',
}) {
  final expected = openingFloat + cashSales + cashIn - cashOut;
  return PosShift(
    id: id,
    branchId: 'b1',
    status: PosShiftStatus.closed,
    openingFloat: openingFloat,
    cashSales: cashSales,
    cardSales: cardSales,
    salesTotal: cashSales + cardSales,
    orderCount: orderCount,
    cashIn: cashIn,
    cashOut: cashOut,
    expectedCash: expected,
    countedCash: countedCash,
    variance: countedCash - expected,
    currencyCode: 'SAR',
    openedByName: 'منى علي',
    closedByName: 'أحمد',
    openedAt: DateTime(2026, 10, 25, 8, 5),
    closedAt: DateTime(2026, 10, 25, 22),
    closeNote: closeNote,
  );
}

void _selectFirstTable(PosCubit cubit, [String id = 't-1']) {
  cubit.selectTable(cubit.state.tableById(id)!);
}

class _FakePosRepository extends AdminPosRepository {
  PosCatalog catalog = _catalog();
  bool failCatalog = false;
  PosCatalogFailure catalogFailure = PosCatalogFailure.failed;
  String? catalogErrorMessage = 'catalog failed';
  int catalogCalls = 0;
  String? lastCatalogBranchId;
  Completer<void>? catalogGate;

  PosOrderResult orderResult = const PosOrderResult(
    orderId: 'o1',
    orderNumber: 'POS-2026-000042',
    subtotal: 40,
    taxTotal: 6,
    grandTotal: 46,
    currencyCode: 'SAR',
    paymentMethodId: 'pay-cash',
    paymentMethodCode: 'cash',
    paymentMethodNameAr: 'نقدي',
    paymentMethodNameEn: 'Cash',
    customerId: 'c-walk',
    customerName: 'منى',
    customerPhone: '01000000000',
    customerSource: 'walk_in',
  );
  PosCheckoutException? checkoutError;
  int orderCalls = 0;
  final List<String> keys = <String>[];
  String? lastKey;
  String? lastBranchId;
  String? lastFulfillment;
  String? lastPaymentMethodId;
  List<Map<String, Object?>>? lastPayments;
  String? lastTableId;
  String? lastNote;
  String? lastCustomerId;
  List<Map<String, Object?>>? lastLines;
  Completer<void>? orderGate;

  List<DiningTable> tables = _floor();
  PosTablesException? tablesError;
  Completer<void>? tablesGate;
  int tableCalls = 0;
  String? lastTablesBranchId;

  PosSeatOutcome seatOutcome = PosSeatOutcome.success;
  Completer<void>? seatGate;
  int seatCalls = 0;
  String? lastReservationId;

  List<PosCustomer> customerResults = <PosCustomer>[];
  List<PosCustomer> Function(String query)? customerSearchHandler;
  PosCustomerException? customerSearchError;
  Completer<void>? customerSearchGate;
  int customerSearchCalls = 0;
  String? lastCustomerQuery;

  PosCustomer? createResult;
  PosCustomerException? customerCreateError;
  int customerCreateCalls = 0;
  String? lastCustomerName;
  String? lastCustomerPhone;
  String? lastCustomerEmail;
  String? lastCustomerNote;

  PosShift? shift = _openShift();
  PosShiftException? shiftError;
  Completer<void>? shiftGate;
  int shiftCalls = 0;
  String? lastShiftBranchId;

  PosShift? openedShift;
  PosShiftException? openShiftError;
  int openShiftCalls = 0;
  double? lastOpeningFloat;
  String? lastOpenShiftNote;
  String? lastOpenShiftCashierId;

  PosShift? movementShift;
  PosShiftException? movementError;
  int movementCalls = 0;
  String? lastMovementShiftId;
  PosCashMovementKind? lastMovementKind;
  double? lastMovementAmount;
  String? lastMovementReason;

  PosShift? closedShiftResult;
  PosShiftException? closeShiftError;
  int closeShiftCalls = 0;
  String? lastCloseShiftId;
  double? lastCountedCash;
  String? lastCloseNote;

  List<PosShift> shiftHistory = const <PosShift>[];
  PosShiftException? shiftHistoryError;
  int shiftHistoryCalls = 0;
  String? lastHistoryBranchId;
  int? lastHistoryLimit;
  int? lastHistoryOffset;

  PosShift? shiftDetailValue;
  PosShiftException? shiftDetailError;
  int shiftDetailCalls = 0;
  String? lastDetailShiftId;

  List<PosCashier> cashiers = const <PosCashier>[];
  PosShiftException? cashiersError;
  int cashierCalls = 0;
  String? lastCashierBranchId;
  Completer<void>? cashiersGate;

  @override
  Future<PosCatalog> loadCatalog({String? branchId}) async {
    catalogCalls += 1;
    lastCatalogBranchId = branchId;
    await catalogGate?.future;
    if (failCatalog) {
      throw PosCatalogException(catalogFailure, catalogErrorMessage);
    }
    final target = branchId ?? catalog.branchId;
    if (target == catalog.branchId) return catalog;
    return PosCatalog(
      branchId: target,
      currencyCode: catalog.currencyCode,
      taxRate: catalog.taxRate,
      taxIncluded: catalog.taxIncluded,
      branches: catalog.branches,
      categories: catalog.categories,
      paymentMethods: catalog.paymentMethods,
      products: catalog.products,
    );
  }

  @override
  Future<List<DiningTable>> loadTables(String branchId) async {
    tableCalls += 1;
    lastTablesBranchId = branchId;
    await tablesGate?.future;
    final error = tablesError;
    if (error != null) throw error;
    return tables
        .where((table) => table.branchId == branchId)
        .toList(growable: false);
  }

  @override
  Future<PosSeatOutcome> seatReservation(String reservationId) async {
    seatCalls += 1;
    lastReservationId = reservationId;
    await seatGate?.future;
    return seatOutcome;
  }

  @override
  Future<PosOrderResult> placeOrder({
    required String branchId,
    required List<Map<String, Object?>> lines,
    required String fulfillmentType,
    required String paymentMethodId,
    required String idempotencyKey,
    String? tableId,
    String? note,
    String? customerId,
    List<Map<String, Object?>>? payments,
  }) async {
    orderCalls += 1;
    lastBranchId = branchId;
    lastFulfillment = fulfillmentType;
    lastPaymentMethodId = paymentMethodId;
    lastPayments = payments;
    lastTableId = tableId;
    lastNote = note;
    lastCustomerId = customerId;
    lastKey = idempotencyKey;
    lastLines = lines;
    keys.add(idempotencyKey);
    await orderGate?.future;
    final error = checkoutError;
    if (error != null) throw error;
    return orderResult;
  }

  @override
  Future<List<PosCustomer>> searchCustomers({String? query}) async {
    customerSearchCalls += 1;
    final normalized = query ?? '';
    lastCustomerQuery = normalized;
    final gate = customerSearchGate;
    await gate?.future;
    final error = customerSearchError;
    if (error != null) throw error;
    return customerSearchHandler?.call(normalized) ?? customerResults;
  }

  @override
  Future<PosCustomer> createCustomer({
    required String fullName,
    String? phone,
    String? email,
    String? note,
  }) async {
    customerCreateCalls += 1;
    lastCustomerName = fullName;
    lastCustomerPhone = phone;
    lastCustomerEmail = email;
    lastCustomerNote = note;
    final error = customerCreateError;
    if (error != null) throw error;
    return createResult ??
        PosCustomer(
          id: 'c-new',
          fullName: fullName,
          phone: phone,
          email: email,
        );
  }

  @override
  Future<PosShift?> loadOpenShift(String branchId) async {
    shiftCalls += 1;
    lastShiftBranchId = branchId;
    await shiftGate?.future;
    final error = shiftError;
    if (error != null) throw error;
    final current = shift;
    if (current == null) return null;
    return current.branchId == branchId ? current : null;
  }

  @override
  Future<PosShift> openShift({
    required String branchId,
    required double openingFloat,
    String? note,
    String? cashierId,
  }) async {
    openShiftCalls += 1;
    lastOpeningFloat = openingFloat;
    lastOpenShiftNote = note;
    lastOpenShiftCashierId = cashierId;
    final error = openShiftError;
    if (error != null) throw error;
    final opened =
        openedShift ??
        _openShift(id: 's-new', branchId: branchId, openingFloat: openingFloat);
    shift = opened;
    return opened;
  }

  @override
  Future<PosShift> recordCashMovement({
    required String shiftId,
    required PosCashMovementKind kind,
    required double amount,
    required String reason,
  }) async {
    movementCalls += 1;
    lastMovementShiftId = shiftId;
    lastMovementKind = kind;
    lastMovementAmount = amount;
    lastMovementReason = reason;
    final error = movementError;
    if (error != null) throw error;
    final updated = movementShift ?? shift ?? _openShift();
    shift = updated;
    return updated;
  }

  @override
  Future<PosShift> closeShift({
    required String shiftId,
    required double countedCash,
    String? closeNote,
  }) async {
    closeShiftCalls += 1;
    lastCloseShiftId = shiftId;
    lastCountedCash = countedCash;
    lastCloseNote = closeNote;
    final error = closeShiftError;
    if (error != null) throw error;
    final closed =
        closedShiftResult ??
        _closedShift(countedCash: countedCash, closeNote: closeNote ?? '');
    shift = null;
    return closed;
  }

  @override
  Future<List<PosShift>> loadShiftHistory(
    String branchId, {
    int limit = 20,
    int offset = 0,
  }) async {
    shiftHistoryCalls += 1;
    lastHistoryBranchId = branchId;
    lastHistoryLimit = limit;
    lastHistoryOffset = offset;
    final error = shiftHistoryError;
    if (error != null) throw error;
    return shiftHistory;
  }

  @override
  Future<PosShift> loadShiftDetail(String shiftId) async {
    shiftDetailCalls += 1;
    lastDetailShiftId = shiftId;
    final error = shiftDetailError;
    if (error != null) throw error;
    return shiftDetailValue ?? _closedShift(id: shiftId);
  }

  @override
  Future<List<PosCashier>> loadCashiers(String branchId) async {
    cashierCalls += 1;
    lastCashierBranchId = branchId;
    await cashiersGate?.future;
    final error = cashiersError;
    if (error != null) throw error;
    return cashiers;
  }
}

int _keySequence = 0;

PosCubit _createCubit(_FakePosRepository repository) {
  _keySequence = 0;
  final cubit = PosCubit(
    repository: repository,
    checkoutKeyFactory: () => 'key-${++_keySequence}',
  );
  addTearDown(cubit.close);
  return cubit;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

const _small = PosOptionValue(id: 'v-small', nameAr: 'صغير', nameEn: 'Small');
const _large = PosOptionValue(
  id: 'v-large',
  nameAr: 'كبير',
  nameEn: 'Large',
  priceDelta: 5,
);
const _oat = PosOptionValue(
  id: 'v-oat',
  nameAr: 'شوفان',
  nameEn: 'Oat milk',
  priceDelta: 2,
);
const _shot = PosOptionValue(
  id: 'v-shot',
  nameAr: 'شوت',
  nameEn: 'Extra shot',
  priceDelta: 3,
);
const _vanilla = PosOptionValue(
  id: 'v-vanilla',
  nameAr: 'فانيليا',
  nameEn: 'Vanilla',
  priceDelta: 1,
);

void main() {
  group('PosCubit load', () {
    test('prepares the branch, cash payment and the menu', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);

      await cubit.load();

      expect(cubit.state.status, PosStatus.ready);
      expect(cubit.state.hasData, isTrue);
      expect(cubit.state.hasProducts, isTrue);
      expect(cubit.state.branches, hasLength(2));
      expect(cubit.state.hasMultipleBranches, isTrue);
      expect(cubit.state.branchId, 'b1');
      expect(cubit.state.selectedBranch?.nameFor(AppLanguage.english), 'Maadi');
      expect(cubit.state.paymentMode, PosPaymentMode.cash);
      expect(cubit.state.selectedPaymentMethod?.isCash, isTrue);
      expect(cubit.state.currencyCode, 'SAR');
      expect(cubit.state.taxRate, 15);
      expect(cubit.state.taxIncluded, isFalse);
      expect(cubit.state.taxApplies, isTrue);
      expect(cubit.state.products, hasLength(3));
      expect(cubit.state.categories, hasLength(2));
      expect(cubit.state.cart, isEmpty);
      expect(cubit.state.canCheckout, isFalse);
      expect(repository.catalogCalls, 1);
      expect(repository.lastCatalogBranchId, isNull);
      expect(repository.tableCalls, 1);
      expect(cubit.state.tables, hasLength(2));
    });

    test('ignores a second load while the first one is in flight', () async {
      final repository = _FakePosRepository()..catalogGate = Completer<void>();
      final cubit = _createCubit(repository);

      final first = cubit.load();
      expect(cubit.state.isLoading, isTrue);
      await cubit.load();
      expect(repository.catalogCalls, 1);

      repository.catalogGate!.complete();
      await first;
      expect(cubit.state.status, PosStatus.ready);
    });

    test('the first failure is retryable', () async {
      final repository = _FakePosRepository()
        ..failCatalog = true
        ..catalogFailure = PosCatalogFailure.noBranch;
      final cubit = _createCubit(repository);

      await cubit.load();

      expect(cubit.state.status, PosStatus.failure);
      expect(cubit.state.isFailure, isTrue);
      expect(cubit.state.hasData, isFalse);
      expect(cubit.state.failure, PosCatalogFailure.noBranch);
      expect(cubit.state.errorMessage, 'catalog failed');

      repository.failCatalog = false;
      await cubit.refresh();

      expect(cubit.state.status, PosStatus.ready);
      expect(cubit.state.failure, isNull);
      expect(cubit.state.errorMessage, isNull);
      expect(repository.catalogCalls, 2);
    });

    test('a failed refresh keeps the menu and reports inline', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();

      repository.failCatalog = true;
      await cubit.refresh();

      expect(cubit.state.status, PosStatus.ready);
      expect(cubit.state.products, hasLength(3));
      expect(cubit.state.isRefreshing, isFalse);
      expect(cubit.state.failure, PosCatalogFailure.failed);
      expect(cubit.state.errorMessage, 'catalog failed');

      repository.failCatalog = false;
      await cubit.refresh();

      expect(cubit.state.failure, isNull);
      expect(cubit.state.errorMessage, isNull);
      expect(repository.catalogCalls, 3);
    });
  });

  group('PosCubit tables', () {
    test('loads the live floor for the active branch', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);

      await cubit.load();

      expect(repository.tableCalls, 1);
      expect(repository.lastTablesBranchId, 'b1');
      expect(cubit.state.tables, hasLength(2));
      expect(cubit.state.hasTables, isTrue);
      expect(cubit.state.selectedTableId, isNull);
      expect(cubit.state.tablesFailure, isNull);
      expect(cubit.state.isLoadingTables, isFalse);

      cubit.selectTable(cubit.state.tableById('t-2'));
      expect(cubit.state.selectedTable?.name, 'طاولة 2');
      _selectFirstTable(cubit);
      expect(cubit.state.selectedTable?.id, 't-1');
      cubit.selectTable(null);
      expect(cubit.state.selectedTableId, isNull);
    });

    test('a table load failure keeps the menu usable and retryable', () async {
      final repository = _FakePosRepository()
        ..tablesError = const PosTablesException(PosTablesFailure.failed);
      final cubit = _createCubit(repository);

      await cubit.load();

      expect(cubit.state.status, PosStatus.ready);
      expect(cubit.state.products, hasLength(3));
      expect(cubit.state.tables, isEmpty);
      expect(cubit.state.tablesFailure, PosTablesFailure.failed);
      expect(cubit.state.isLoadingTables, isFalse);

      repository.tablesError = null;
      await cubit.refreshTables();

      expect(cubit.state.tables, hasLength(2));
      expect(cubit.state.tablesFailure, isNull);
      expect(cubit.state.isLoadingTables, isFalse);
    });

    test('a refresh drops the table when it stops being selectable', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();
      _selectFirstTable(cubit);

      repository.tables = <DiningTable>[
        _table(
          id: 't-1',
          name: 'طاولة 1',
          status: DiningTableStatus.occupied,
          activeOrder: const DiningActiveOrder(
            id: 'o1',
            orderNumber: 'POS-1',
            grandTotal: 40,
          ),
        ),
        _table(id: 't-2', name: 'طاولة 2'),
      ];

      await cubit.refreshTables();

      expect(cubit.state.tables, hasLength(2));
      expect(cubit.state.selectedTableId, isNull);
      expect(cubit.state.tables.first.isPosSelectable, isFalse);
    });

    test('seating a booking marks it seated and selects its table', () async {
      final repository = _FakePosRepository()
        ..tables = <DiningTable>[
          _table(
            id: 't-3',
            name: 'غرفة 3',
            area: DiningArea.privateRoom,
            status: DiningTableStatus.reserved,
            reservation: _reservation(tableId: 't-3'),
          ),
        ];
      final cubit = _createCubit(repository);
      await cubit.load();

      expect(cubit.state.tables.single.canSeatGuest, isTrue);
      expect(cubit.state.tables.single.isPosSelectable, isFalse);

      repository.tables = <DiningTable>[
        _table(
          id: 't-3',
          name: 'غرفة 3',
          area: DiningArea.privateRoom,
          status: DiningTableStatus.seated,
          reservation: _reservation(
            tableId: 't-3',
            status: DiningReservationStatus.seated,
          ),
        ),
      ];

      final outcome = await cubit.seatReservation(cubit.state.tables.single);

      expect(outcome, PosSeatOutcome.success);
      expect(repository.seatCalls, 1);
      expect(repository.lastReservationId, 'r-1');
      expect(repository.tableCalls, 2);
      expect(cubit.state.isSeating, isFalse);
      expect(cubit.state.selectedTableId, 't-3');
      expect(cubit.state.selectedTable?.status, DiningTableStatus.seated);
    });

    test('a refused seating leaves the sale without a table', () async {
      final repository = _FakePosRepository()
        ..seatOutcome = PosSeatOutcome.tooEarly
        ..tables = <DiningTable>[
          _table(
            id: 't-3',
            name: 'غرفة 3',
            status: DiningTableStatus.reserved,
            reservation: _reservation(tableId: 't-3'),
          ),
        ];
      final cubit = _createCubit(repository);
      await cubit.load();

      final outcome = await cubit.seatReservation(cubit.state.tables.single);

      expect(outcome, PosSeatOutcome.tooEarly);
      expect(cubit.state.selectedTableId, isNull);
      expect(cubit.state.isSeating, isFalse);
      expect(repository.tableCalls, 1);
    });

    test('a taken table at checkout is released and refreshed', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();
      cubit.addToCart(cubit.state.productById('p-latte')!);
      _selectFirstTable(cubit);

      repository.tables = <DiningTable>[
        _table(id: 't-1', name: 'طاولة 1', status: DiningTableStatus.occupied),
        _table(id: 't-2', name: 'طاولة 2'),
      ];
      repository.checkoutError = const PosCheckoutException(
        PosCheckoutFailure.tableUnavailable,
      );

      expect(await cubit.placeOrder(), PosCheckoutOutcome.tableUnavailable);
      expect(cubit.state.selectedTableId, isNull);
      expect(cubit.state.cart, hasLength(1));
      expect(cubit.state.isPlacingOrder, isFalse);

      await _settle();
      expect(repository.tableCalls, 2);
      expect(cubit.state.tables.first.status, DiningTableStatus.occupied);
    });
  });

  group('PosCubit shifts', () {
    test('the drawer blocks checkout until the cashier opens it', () async {
      final repository = _FakePosRepository()..shift = null;
      final cubit = _createCubit(repository);

      await cubit.load();

      expect(repository.shiftCalls, 1);
      expect(repository.lastShiftBranchId, 'b1');
      expect(cubit.state.shiftKnown, isTrue);
      expect(cubit.state.shift, isNull);
      expect(cubit.state.shiftMissing, isTrue);
      expect(cubit.state.isLoadingShift, isFalse);

      cubit.addToCart(cubit.state.productById('p-latte')!);
      expect(cubit.state.checkoutBlocker, PosCheckoutBlocker.shiftMissing);
      expect(await cubit.placeOrder(), PosCheckoutOutcome.shiftRequired);
      expect(repository.orderCalls, 0);

      final opened = await cubit.openShift(
        openingFloat: 150,
        note: 'درج الصباح',
      );

      expect(opened?.openingFloat, 150);
      expect(repository.openShiftCalls, 1);
      expect(repository.lastOpeningFloat, 150);
      expect(repository.lastOpenShiftNote, 'درج الصباح');
      expect(cubit.state.shift?.openingFloat, 150);
      expect(cubit.state.shiftMissing, isFalse);
      expect(cubit.state.isOpeningShift, isFalse);
      expect(cubit.state.checkoutBlocker, isNull);

      expect(await cubit.placeOrder(), PosCheckoutOutcome.success);
      expect(repository.orderCalls, 1);
      await _settle();
    });

    test('an open drawer loads its live totals with the menu', () async {
      final repository = _FakePosRepository()
        ..shift = _openShift(
          openingFloat: 120,
          cashSales: 40,
          cardSales: 25,
          cashIn: 10,
          cashOut: 5,
          orderCount: 3,
        );
      final cubit = _createCubit(repository);

      await cubit.load();

      expect(cubit.state.shift, isNotNull);
      expect(cubit.state.hasOpenShift, isTrue);
      expect(cubit.state.shift?.expectedCash, 165);
      expect(cubit.state.shift?.salesTotal, 65);
      expect(cubit.state.shift?.openingFloat, 120);
      expect(cubit.state.shiftKnown, isTrue);
      expect(cubit.state.shiftFailure, isNull);
      expect(cubit.state.isLoadingShift, isFalse);
    });

    test('a shift outage never blocks the sale', () async {
      final repository = _FakePosRepository()
        ..shiftError = const PosShiftException(
          PosShiftFailure.failed,
          'shift service down',
        );
      final cubit = _createCubit(repository);

      await cubit.load();

      expect(cubit.state.status, PosStatus.ready);
      expect(cubit.state.shiftKnown, isFalse);
      expect(cubit.state.shiftMissing, isFalse);
      expect(cubit.state.shiftFailure, PosShiftFailure.failed);
      expect(cubit.state.isLoadingShift, isFalse);

      cubit.addToCart(cubit.state.productById('p-latte')!);
      expect(cubit.state.checkoutBlocker, isNull);
      expect(await cubit.placeOrder(), PosCheckoutOutcome.success);
      expect(repository.orderCalls, 1);
      await _settle();
    });

    test(
      'a server shift requirement closes the drawer and stops the sale',
      () async {
        final repository = _FakePosRepository();
        final cubit = _createCubit(repository);
        await cubit.load();
        cubit.addToCart(cubit.state.productById('p-latte')!);

        repository.checkoutError = const PosCheckoutException(
          PosCheckoutFailure.shiftRequired,
        );

        expect(await cubit.placeOrder(), PosCheckoutOutcome.shiftRequired);
        expect(cubit.state.shift, isNull);
        expect(cubit.state.shiftKnown, isTrue);
        expect(cubit.state.shiftMissing, isTrue);
        expect(cubit.state.cart, hasLength(1));
        expect(cubit.state.isPlacingOrder, isFalse);
        expect(repository.orderCalls, 1);

        expect(await cubit.placeOrder(), PosCheckoutOutcome.shiftRequired);
        expect(repository.orderCalls, 1);

        repository.checkoutError = null;
        await cubit.openShift(openingFloat: 50);

        expect(cubit.state.shiftMissing, isFalse);
        expect(await cubit.placeOrder(), PosCheckoutOutcome.success);
        expect(repository.orderCalls, 2);
        await _settle();
      },
    );

    test('a cash movement updates the expected drawer', () async {
      final repository = _FakePosRepository()
        ..shift = _openShift(openingFloat: 100);
      final cubit = _createCubit(repository);
      await cubit.load();

      repository.movementShift = _openShift(openingFloat: 100, cashIn: 30);

      final updated = await cubit.recordCashMovement(
        kind: PosCashMovementKind.cashIn,
        amount: 30,
        reason: 'فكة',
      );

      expect(updated?.cashIn, 30);
      expect(updated?.expectedCash, 130);
      expect(repository.movementCalls, 1);
      expect(repository.lastMovementShiftId, 's-1');
      expect(repository.lastMovementKind, PosCashMovementKind.cashIn);
      expect(repository.lastMovementAmount, 30);
      expect(repository.lastMovementReason, 'فكة');
      expect(cubit.state.shift?.cashIn, 30);
      expect(cubit.state.isSavingMovement, isFalse);

      expect(
        await cubit.recordCashMovement(
          kind: PosCashMovementKind.cashOut,
          amount: 0,
          reason: 'فكة',
        ),
        isNull,
      );
      expect(repository.movementCalls, 1);
    });

    test('a rejected movement keeps the drawer on screen', () async {
      final repository = _FakePosRepository()
        ..shift = _openShift()
        ..movementError = const PosShiftException(
          PosShiftFailure.permissionDenied,
          'denied',
        );
      final cubit = _createCubit(repository);
      await cubit.load();

      final updated = await cubit.recordCashMovement(
        kind: PosCashMovementKind.cashOut,
        amount: 15,
        reason: 'مصاريف',
      );

      expect(updated, isNull);
      expect(cubit.state.shift, isNotNull);
      expect(cubit.state.shiftFailure, PosShiftFailure.permissionDenied);
      expect(cubit.state.isSavingMovement, isFalse);
    });

    test(
      'closing the drawer snapshots the variance and clears the sale',
      () async {
        final repository = _FakePosRepository()
          ..shift = _openShift(
            openingFloat: 100,
            cashSales: 40,
            cashIn: 10,
            cashOut: 5,
          );
        final cubit = _createCubit(repository);
        await cubit.load();
        cubit.addToCart(cubit.state.productById('p-latte')!);

        repository.closedShiftResult = _closedShift(countedCash: 140);

        final closed = await cubit.closeShift(countedCash: 140, note: 'ناقص');

        expect(closed?.isClosed, isTrue);
        expect(closed?.variance, -5);
        expect(closed?.isShort, isTrue);
        expect(repository.closeShiftCalls, 1);
        expect(repository.lastCloseShiftId, 's-1');
        expect(repository.lastCountedCash, 140);
        expect(repository.lastCloseNote, 'ناقص');
        expect(cubit.state.shift, isNull);
        expect(cubit.state.shiftKnown, isTrue);
        expect(cubit.state.shiftMissing, isTrue);
        expect(cubit.state.isClosingShift, isFalse);
        expect(cubit.state.cart, hasLength(1));
        expect(cubit.state.shiftHistory, isEmpty);
      },
    );

    test('a rejected close leaves the drawer open for a recount', () async {
      final repository = _FakePosRepository()
        ..shift = _openShift()
        ..closeShiftError = const PosShiftException(
          PosShiftFailure.alreadyClosed,
          'shift changed',
        );
      final cubit = _createCubit(repository);
      await cubit.load();

      final closed = await cubit.closeShift(countedCash: 100);

      expect(closed, isNull);
      expect(cubit.state.shift, isNotNull);
      expect(cubit.state.shiftFailure, PosShiftFailure.alreadyClosed);
      expect(cubit.state.isClosingShift, isFalse);
    });

    test('history pages append once and skip duplicates', () async {
      final firstPage = <PosShift>[
        for (var index = PosState.shiftHistoryPageSize; index >= 1; index--)
          _closedShift(id: 's-$index'),
      ];
      final repository = _FakePosRepository()..shiftHistory = firstPage;
      final cubit = _createCubit(repository);
      await cubit.load();

      await cubit.loadShiftHistory();

      expect(repository.shiftHistoryCalls, 1);
      expect(repository.lastHistoryBranchId, 'b1');
      expect(repository.lastHistoryLimit, PosState.shiftHistoryPageSize);
      expect(repository.lastHistoryOffset, 0);
      expect(
        cubit.state.shiftHistory,
        hasLength(PosState.shiftHistoryPageSize),
      );
      expect(cubit.state.isLoadingShiftHistory, isFalse);
      expect(cubit.state.hasShiftHistory, isTrue);
      expect(cubit.state.canLoadMoreShiftHistory, isTrue);

      repository.shiftHistory = <PosShift>[
        _closedShift(id: 's-1'),
        _closedShift(id: 's-0'),
      ];
      await cubit.loadShiftHistory(append: true);

      expect(repository.lastHistoryOffset, PosState.shiftHistoryPageSize);
      expect(
        cubit.state.shiftHistory,
        hasLength(PosState.shiftHistoryPageSize + 1),
      );
      expect(cubit.state.shiftHistory.last.id, 's-0');
      expect(cubit.state.canLoadMoreShiftHistory, isFalse);
    });

    test('history failures stay inline and retry', () async {
      final repository = _FakePosRepository()
        ..shiftHistoryError = const PosShiftException(PosShiftFailure.failed);
      final cubit = _createCubit(repository);
      await cubit.load();

      await cubit.loadShiftHistory();

      expect(cubit.state.shiftHistory, isEmpty);
      expect(cubit.state.shiftHistoryFailure, PosShiftFailure.failed);
      expect(cubit.state.isLoadingShiftHistory, isFalse);

      repository.shiftHistoryError = null;
      repository.shiftHistory = <PosShift>[_closedShift(id: 's-9')];
      await cubit.loadShiftHistory();

      expect(cubit.state.shiftHistoryFailure, isNull);
      expect(cubit.state.shiftHistory.single.id, 's-9');
    });

    test('a shift detail loads the Z report or reports in history', () async {
      final repository = _FakePosRepository()
        ..shiftHistory = <PosShift>[_closedShift(id: 's-2')]
        ..shiftDetailValue = _closedShift(id: 's-2', closeNote: 'تم');
      final cubit = _createCubit(repository);
      await cubit.load();
      await cubit.loadShiftHistory();

      final detail = await cubit.loadShiftDetail('s-2');

      expect(detail?.id, 's-2');
      expect(cubit.state.shiftDetail?.closeNote, 'تم');
      expect(cubit.state.isLoadingShiftDetail, isFalse);
      expect(repository.lastDetailShiftId, 's-2');

      repository.shiftDetailError = const PosShiftException(
        PosShiftFailure.permissionDenied,
        'denied',
      );

      expect(await cubit.loadShiftDetail('s-9'), isNull);
      expect(cubit.state.shiftDetail, isNull);
      expect(cubit.state.shiftHistoryFailure, PosShiftFailure.permissionDenied);
      expect(cubit.state.shiftFailure, isNull);
      expect(cubit.state.shiftHistory, hasLength(1));
    });
  });

  group('PosCubit shift cashier', () {
    test(
      'reads the staff who may own the drawer of the selected branch',
      () async {
        final repository = _FakePosRepository()
          ..cashiers = const <PosCashier>[
            PosCashier(id: 'st-1', fullName: 'منى علي', isSelf: true),
            PosCashier(id: 'st-2', fullName: 'سامي حسن'),
          ];
        final cubit = _createCubit(repository);
        await cubit.load();

        await cubit.loadCashiers();

        expect(repository.cashierCalls, 1);
        expect(repository.lastCashierBranchId, 'b1');
        expect(cubit.state.cashiers, hasLength(2));
        expect(cubit.state.cashiers.first.isSelf, isTrue);
        expect(cubit.state.isLoadingCashiers, isFalse);
        expect(cubit.state.cashiersFailure, isNull);
      },
    );

    test('reads nothing until a branch is selected', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);

      await cubit.loadCashiers();

      expect(repository.cashierCalls, 0);
      expect(cubit.state.isLoadingCashiers, isFalse);
    });

    test('a failed cashier read keeps the self-open path usable', () async {
      final repository = _FakePosRepository()
        ..shift = null
        ..cashiersError = const PosShiftException(
          PosShiftFailure.permissionDenied,
          'denied',
        );
      final cubit = _createCubit(repository);
      await cubit.load();

      await cubit.loadCashiers();

      expect(cubit.state.cashiers, isEmpty);
      expect(cubit.state.cashiersFailure, PosShiftFailure.permissionDenied);
      expect(cubit.state.isLoadingCashiers, isFalse);

      final opened = await cubit.openShift(openingFloat: 100);

      expect(opened, isNotNull);
      expect(repository.lastOpenShiftCashierId, isNull);
    });

    test('the chosen cashier is sent and no choice means the caller', () async {
      final repository = _FakePosRepository()..shift = null;
      final cubit = _createCubit(repository);
      await cubit.load();

      final assigned = await cubit.openShift(
        openingFloat: 120,
        cashierId: 'st-2',
      );
      expect(assigned, isNotNull);
      expect(repository.lastOpenShiftCashierId, 'st-2');

      final second = await cubit.openShift(openingFloat: 60);
      expect(second, isNotNull);
      expect(repository.lastOpenShiftCashierId, isNull);
      expect(repository.openShiftCalls, 2);
    });

    test('switching branches drops the cashiers of the old branch', () async {
      final repository = _FakePosRepository()
        ..cashiers = const <PosCashier>[
          PosCashier(id: 'st-2', fullName: 'سامي'),
        ];
      final cubit = _createCubit(repository);
      await cubit.load();
      await cubit.loadCashiers();

      await cubit.setBranch('b2');

      expect(cubit.state.cashiers, isEmpty);
      expect(cubit.state.isLoadingCashiers, isFalse);

      await cubit.loadCashiers();

      expect(repository.cashierCalls, 2);
      expect(repository.lastCashierBranchId, 'b2');
    });

    test('a slow cashier read cannot land after the branch changed', () async {
      final repository = _FakePosRepository()
        ..cashiers = const <PosCashier>[
          PosCashier(id: 'st-2', fullName: 'سامي'),
        ];
      final cubit = _createCubit(repository);
      await cubit.load();

      repository.cashiersGate = Completer<void>();
      final first = cubit.loadCashiers();
      await _settle();
      expect(cubit.state.isLoadingCashiers, isTrue);

      await cubit.setBranch('b2');
      repository.cashiersGate!.complete();
      await first;

      expect(cubit.state.cashiers, isEmpty);
      expect(cubit.state.isLoadingCashiers, isFalse);
    });
  });

  group('PosCubit filters and branch', () {
    test('switching branches clears the sale and reloads the menu', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();

      cubit.addToCart(cubit.state.productById('p-latte')!, quantity: 2);
      cubit.selectCustomer(
        const PosCustomer(id: 'c-walk', fullName: 'منى', phone: '01000000000'),
      );
      _selectFirstTable(cubit);
      cubit.setOrderNote('serve together');
      cubit.selectPaymentMode(PosPaymentMode.card);

      await cubit.setBranch('b2');

      expect(repository.lastCatalogBranchId, 'b2');
      expect(repository.catalogCalls, 2);
      expect(repository.lastTablesBranchId, 'b2');
      expect(repository.tableCalls, 2);
      expect(cubit.state.status, PosStatus.ready);
      expect(cubit.state.branchId, 'b2');
      expect(cubit.state.cart, isEmpty);
      expect(cubit.state.customer, isNull);
      expect(cubit.state.selectedTable, isNull);
      expect(cubit.state.tables, isEmpty);
      expect(cubit.state.orderNote, isEmpty);
      expect(cubit.state.paymentMode, PosPaymentMode.cash);
      expect(cubit.state.splitCash, 0);

      await cubit.setBranch('b2');
      await cubit.setBranch('missing');
      expect(repository.catalogCalls, 2);
      expect(cubit.state.branchId, 'b2');
    });

    test('search and category filters narrow the menu and clear', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();

      expect(cubit.state.visibleProducts, hasLength(3));

      cubit.updateSearch('  tea ');
      expect(cubit.state.search, 'tea');
      expect(cubit.state.visibleProducts.map((product) => product.id), [
        'p-tea',
      ]);
      expect(cubit.state.hasActiveFilters, isTrue);

      cubit.updateSearch('mo');
      expect(cubit.state.visibleProducts.map((product) => product.id), [
        'p-mocha',
      ]);

      cubit.updateSearch('');
      expect(cubit.state.hasActiveFilters, isFalse);
      expect(cubit.state.visibleProducts, hasLength(3));

      cubit.setCategory('coffee');
      expect(cubit.state.categoryId, 'coffee');
      expect(
        cubit.state.selectedCategory?.nameFor(AppLanguage.english),
        'Coffee',
      );
      expect(cubit.state.visibleProducts.map((product) => product.id), [
        'p-latte',
        'p-tea',
      ]);

      cubit.setCategory('missing');
      expect(cubit.state.categoryId, 'coffee');
      cubit.setCategory(null);
      expect(cubit.state.categoryId, isNull);

      cubit.updateSearch('latte');
      cubit.setCategory('coffee');
      expect(cubit.state.hasActiveFilters, isTrue);
      cubit.clearFilters();
      expect(cubit.state.search, isEmpty);
      expect(cubit.state.categoryId, isNull);
      expect(cubit.state.hasActiveFilters, isFalse);
      expect(cubit.state.visibleProducts, hasLength(3));
    });
  });

  group('PosCubit cart', () {
    test('merges identical lines and stops at the stock limit', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();

      final latte = cubit.state.productById('p-latte')!;
      expect(cubit.addToCart(latte), isTrue);
      expect(cubit.addToCart(latte, quantity: 2), isTrue);
      expect(cubit.state.cart, hasLength(1));
      expect(cubit.state.cart.single.quantity, 3);
      expect(cubit.state.cartQuantity, 3);
      expect(cubit.state.quantityOf('p-latte'), 3);
      expect(cubit.state.remainingFor(latte), 2);

      expect(cubit.addToCart(latte, quantity: 10), isTrue);
      expect(cubit.state.cart.single.quantity, 5);
      expect(cubit.state.remainingFor(latte), 0);
      expect(cubit.addToCart(latte), isFalse);

      final tea = cubit.state.productById('p-tea')!;
      expect(cubit.addToCart(tea, quantity: 120), isTrue);
      expect(cubit.state.cart.last.quantity, 99);
      expect(cubit.addToCart(tea), isFalse);

      expect(cubit.addToCart(tea, note: 'no sugar'), isTrue);
      expect(cubit.addToCart(tea, note: ' no sugar '), isTrue);
      expect(cubit.state.cart, hasLength(3));
      expect(cubit.state.cart.last.quantity, 2);
      expect(cubit.state.cart.last.note, 'no sugar');
      expect(cubit.state.cartQuantity, 5 + 99 + 2);
    });

    test('options are validated against the product groups', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();

      final mocha = cubit.state.productById('p-mocha')!;
      expect(cubit.addToCart(mocha), isFalse);
      expect(cubit.state.cart, isEmpty);

      expect(cubit.addToCart(mocha, options: const [_small]), isTrue);
      expect(cubit.state.cart.single.unitPrice, 30);
      expect(
        cubit.state.cart.single.optionsLabel(AppLanguage.english),
        'Small',
      );

      expect(
        cubit.addToCart(mocha, options: const [_large, _oat, _shot]),
        isTrue,
      );
      expect(cubit.state.cart, hasLength(2));
      expect(cubit.state.cart.last.unitPrice, 40);
      expect(
        cubit.state.cart.last.optionsLabel(AppLanguage.english),
        'Large · Oat milk · Extra shot',
      );

      expect(
        cubit.addToCart(mocha, options: const [_small, _oat, _shot, _vanilla]),
        isFalse,
      );
      expect(
        cubit.addToCart(
          mocha,
          options: const [
            _small,
            PosOptionValue(id: 'v-unknown'),
          ],
        ),
        isFalse,
      );
      expect(cubit.state.cart, hasLength(2));
    });

    test('summary matches the server pricing and tax rules', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();

      cubit.addToCart(cubit.state.productById('p-latte')!, quantity: 2);
      cubit.addToCart(
        cubit.state.productById('p-mocha')!,
        options: const [_small],
      );

      expect(cubit.state.cartSummary.subtotal, 70);
      expect(cubit.state.cartSummary.tax, 10.5);
      expect(cubit.state.cartSummary.total, 80.5);
      expect(cubit.state.cartSummary.quantity, 3);
      expect(cubit.state.checkoutBlocker, isNull);
      expect(cubit.state.canCheckout, isTrue);

      cubit.selectTable(cubit.state.tableById('t-2'));
      expect(cubit.state.checkoutBlocker, isNull);
      expect(cubit.state.canCheckout, isTrue);
    });

    test('included tax never adds to the total', () async {
      final repository = _FakePosRepository()
        ..catalog = _catalog(taxIncluded: true);
      final cubit = _createCubit(repository);
      await cubit.load();

      cubit.addToCart(cubit.state.productById('p-latte')!, quantity: 2);

      expect(cubit.state.taxApplies, isFalse);
      expect(cubit.state.cartSummary.subtotal, 40);
      expect(cubit.state.cartSummary.tax, 0);
      expect(cubit.state.cartSummary.total, 40);
    });

    test('line quantities follow the stock cap and zero removes', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();

      cubit.addToCart(cubit.state.productById('p-latte')!);
      final key = cubit.state.cart.single.key;

      expect(cubit.incrementLine('missing'), isFalse);
      for (var i = 0; i < 4; i++) {
        expect(cubit.incrementLine(key), isTrue);
      }
      expect(cubit.state.cart.single.quantity, 5);
      expect(cubit.incrementLine(key), isFalse);

      expect(cubit.setLineQuantity(key, 7), isFalse);
      expect(cubit.state.cart.single.quantity, 5);
      expect(cubit.setLineQuantity(key, 3), isTrue);
      expect(cubit.state.cart.single.quantity, 3);
      expect(cubit.decrementLine(key), isTrue);
      expect(cubit.state.cart.single.quantity, 2);

      expect(cubit.setLineQuantity(key, 0), isTrue);
      expect(cubit.state.cart, isEmpty);
      expect(cubit.decrementLine(key), isFalse);

      cubit.addToCart(cubit.state.productById('p-latte')!);
      expect(cubit.decrementLine(cubit.state.cart.single.key), isTrue);
      expect(cubit.state.cart, isEmpty);
    });
  });

  group('PosCubit customers', () {
    const registered = PosCustomer(
      id: 'c-reg',
      source: PosCustomerSource.registered,
      fullName: 'أحمد محمد',
      phone: '01000000001',
      isVip: true,
      ordersCount: 4,
    );
    const walkIn = PosCustomer(
      id: 'c-walk',
      fullName: 'منى',
      phone: '01000000000',
    );

    test('search trims the query and publishes the directory', () async {
      final repository = _FakePosRepository()
        ..customerResults = [registered, walkIn];
      final cubit = _createCubit(repository);
      await cubit.load();

      await cubit.searchCustomers('  أحمد ');

      expect(repository.customerSearchCalls, 1);
      expect(repository.lastCustomerQuery, 'أحمد');
      expect(cubit.state.customerQuery, 'أحمد');
      expect(cubit.state.customerResults.map((customer) => customer.id), [
        'c-reg',
        'c-walk',
      ]);
      expect(cubit.state.isSearchingCustomers, isFalse);
      expect(cubit.state.customerFailure, isNull);
      expect(cubit.state.hasCustomerSearch, isTrue);

      cubit.resetCustomerSearch();

      expect(cubit.state.customerResults, isEmpty);
      expect(cubit.state.customerQuery, isEmpty);
      expect(cubit.state.customerFailure, isNull);
      expect(cubit.state.hasCustomerSearch, isFalse);
    });

    test('an empty search lists the most recent customers', () async {
      final repository = _FakePosRepository()..customerResults = [walkIn];
      final cubit = _createCubit(repository);
      await cubit.load();

      await cubit.searchCustomers('   ');

      expect(repository.lastCustomerQuery, isEmpty);
      expect(cubit.state.customerResults.single.id, 'c-walk');
    });

    test('only the latest search result is published', () async {
      final repository = _FakePosRepository()
        ..customerSearchGate = Completer<void>()
        ..customerSearchHandler = (query) => [
          PosCustomer(id: 'c-$query', fullName: query),
        ];
      final cubit = _createCubit(repository);
      await cubit.load();

      final first = cubit.searchCustomers('أحمد');
      final second = cubit.searchCustomers('منى');
      expect(cubit.state.customerQuery, 'منى');
      expect(cubit.state.isSearchingCustomers, isTrue);

      repository.customerSearchGate!.complete();
      await Future.wait([first, second]);

      expect(cubit.state.customerQuery, 'منى');
      expect(cubit.state.customerResults.single.id, 'c-منى');
      expect(cubit.state.isSearchingCustomers, isFalse);
    });

    test(
      'a branch switch discards the customer and pending searches',
      () async {
        final repository = _FakePosRepository()
          ..customerSearchGate = Completer<void>();
        final cubit = _createCubit(repository);
        await cubit.load();
        cubit.selectCustomer(walkIn);

        final pending = cubit.searchCustomers('منى');
        await cubit.setBranch('b2');
        repository.customerSearchGate!.complete();
        await pending;

        expect(cubit.state.branchId, 'b2');
        expect(cubit.state.customer, isNull);
        expect(cubit.state.customerResults, isEmpty);
        expect(cubit.state.customerQuery, isEmpty);
        expect(cubit.state.isSearchingCustomers, isFalse);
      },
    );

    test('a search failure keeps the dialog retryable', () async {
      final repository = _FakePosRepository()
        ..customerSearchError = const PosCustomerException(
          PosCustomerFailure.permissionDenied,
          'denied',
        );
      final cubit = _createCubit(repository);
      await cubit.load();

      await cubit.searchCustomers('أحمد');

      expect(cubit.state.customerFailure, PosCustomerFailure.permissionDenied);
      expect(cubit.state.customerResults, isEmpty);
      expect(cubit.state.isSearchingCustomers, isFalse);

      repository.customerSearchError = null;
      repository.customerResults = [registered];
      await cubit.searchCustomers('أحمد');

      expect(cubit.state.customerFailure, isNull);
      expect(cubit.state.customerResults.single.id, 'c-reg');
    });

    test('creating a counter customer selects and prepends it', () async {
      final repository = _FakePosRepository()..customerResults = [registered];
      final cubit = _createCubit(repository);
      await cubit.load();
      await cubit.searchCustomers('');

      final created = await cubit.createCustomer(
        fullName: 'سارة',
        phone: '01122233344',
        email: 'sara@example.com',
        note: 'يفضل بلا سكر',
      );

      expect(repository.customerCreateCalls, 1);
      expect(repository.lastCustomerName, 'سارة');
      expect(repository.lastCustomerPhone, '01122233344');
      expect(repository.lastCustomerEmail, 'sara@example.com');
      expect(repository.lastCustomerNote, 'يفضل بلا سكر');
      expect(created!.id, 'c-new');
      expect(cubit.state.customer!.id, 'c-new');
      expect(cubit.state.customer!.fullName, 'سارة');
      expect(cubit.state.customerResults.map((customer) => customer.id), [
        'c-new',
        'c-reg',
      ]);
      expect(cubit.state.customerQuery, isEmpty);
      expect(cubit.state.isCreatingCustomer, isFalse);
    });

    test('an existing counter customer is reused, not duplicated', () async {
      final repository = _FakePosRepository()
        ..customerResults = [walkIn, registered]
        ..createResult = const PosCustomer(
          id: 'c-walk',
          fullName: 'منى',
          phone: '01000000000',
          reused: true,
        );
      final cubit = _createCubit(repository);
      await cubit.load();
      await cubit.searchCustomers('منى');

      final created = await cubit.createCustomer(
        fullName: 'منى',
        phone: '01000000000',
      );

      expect(created!.reused, isTrue);
      expect(cubit.state.customer!.reused, isTrue);
      expect(cubit.state.customerResults.map((customer) => customer.id), [
        'c-walk',
        'c-reg',
      ]);
    });

    test('a create failure leaves the customer unselected', () async {
      final repository = _FakePosRepository()
        ..customerCreateError = const PosCustomerException(
          PosCustomerFailure.invalid,
          'phone invalid',
        );
      final cubit = _createCubit(repository);
      await cubit.load();

      final created = await cubit.createCustomer(fullName: 'سارة');

      expect(created, isNull);
      expect(cubit.state.customer, isNull);
      expect(cubit.state.customerFailure, PosCustomerFailure.invalid);
      expect(cubit.state.isCreatingCustomer, isFalse);

      repository.customerCreateError = null;
      final retry = await cubit.createCustomer(fullName: 'سارة');

      expect(retry, isNotNull);
      expect(cubit.state.customerFailure, isNull);
      expect(cubit.state.customer!.fullName, 'سارة');
    });

    test('changing the customer starts a new checkout attempt', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();
      cubit.addToCart(cubit.state.productById('p-latte')!);
      _selectFirstTable(cubit);
      repository.checkoutError = const PosCheckoutException(
        PosCheckoutFailure.failed,
      );

      await cubit.placeOrder();
      cubit.selectCustomer(walkIn);
      await cubit.placeOrder();
      cubit.selectCustomer(walkIn);
      await cubit.placeOrder();
      cubit.selectCustomer(null);
      await cubit.placeOrder();

      expect(repository.keys, ['key-1', 'key-2', 'key-2', 'key-3']);
      expect(repository.orderCalls, 4);
    });

    test('customer changes are blocked while the order is sending', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();
      cubit.addToCart(cubit.state.productById('p-latte')!);
      _selectFirstTable(cubit);
      cubit.selectCustomer(walkIn);

      repository.orderGate = Completer<void>();
      final pending = cubit.placeOrder();
      await Future<void>.delayed(Duration.zero);

      cubit.selectCustomer(null);
      expect(cubit.state.customer!.id, 'c-walk');
      expect(await cubit.createCustomer(fullName: 'سارة'), isNull);
      expect(repository.customerCreateCalls, 0);

      repository.orderGate!.complete();
      expect(await pending, PosCheckoutOutcome.success);
      await _settle();
    });

    test('an unavailable customer keeps the sale open for a retry', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();
      cubit.addToCart(cubit.state.productById('p-latte')!);
      _selectFirstTable(cubit);
      cubit.selectCustomer(walkIn);

      repository.checkoutError = const PosCheckoutException(
        PosCheckoutFailure.customerUnavailable,
      );

      expect(await cubit.placeOrder(), PosCheckoutOutcome.customerUnavailable);
      expect(cubit.state.customer!.id, 'c-walk');
      expect(cubit.state.cart, hasLength(1));
      expect(cubit.state.isPlacingOrder, isFalse);

      cubit.selectCustomer(null);
      repository.checkoutError = null;
      expect(await cubit.placeOrder(), PosCheckoutOutcome.success);
      expect(repository.keys, ['key-1', 'key-2']);
      expect(repository.lastCustomerId, isNull);
      await _settle();
    });
  });

  group('PosCubit checkout', () {
    test('a dine-in sale sends the cart and opens the receipt', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();

      cubit.addToCart(
        cubit.state.productById('p-latte')!,
        quantity: 2,
        note: ' extra hot ',
      );
      cubit.addToCart(
        cubit.state.productById('p-mocha')!,
        options: const [_small],
      );
      cubit.selectCustomer(
        const PosCustomer(id: 'c-walk', fullName: 'منى', phone: '01000000000'),
      );
      _selectFirstTable(cubit);
      cubit.setOrderNote(' serve together ');
      cubit.selectPaymentMode(PosPaymentMode.card);

      final outcome = await cubit.placeOrder();

      expect(outcome, PosCheckoutOutcome.success);
      expect(repository.orderCalls, 1);
      expect(repository.lastBranchId, 'b1');
      expect(repository.lastFulfillment, 'dine_in');
      expect(repository.lastPaymentMethodId, 'pay-card');
      expect(repository.lastTableId, 't-1');
      expect(repository.lastNote, ' serve together ');
      expect(repository.lastCustomerId, 'c-walk');
      expect(repository.lastLines, [
        {'product_id': 'p-latte', 'quantity': 2, 'note': 'extra hot'},
        {
          'product_id': 'p-mocha',
          'quantity': 1,
          'option_value_ids': ['v-small'],
        },
      ]);
      expect(repository.keys, ['key-1']);

      final receipt = cubit.state.lastReceipt!;
      expect(receipt.orderNumber, 'POS-2026-000042');
      expect(receipt.itemCount, 3);
      expect(receipt.orderNote, 'serve together');
      expect(receipt.lines, hasLength(2));
      expect(receipt.lines.first.quantity, 2);
      expect(receipt.result.customerDisplayName, 'منى');
      expect(receipt.result.customerPhone, '01000000000');
      expect(cubit.state.cart, isEmpty);
      expect(cubit.state.customer, isNull);
      expect(cubit.state.customerResults, isEmpty);
      expect(cubit.state.selectedTableId, isNull);
      expect(cubit.state.orderNote, isEmpty);
      expect(cubit.state.isPlacingOrder, isFalse);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.paymentMode, PosPaymentMode.card);

      await _settle();
      expect(repository.catalogCalls, 2);
      expect(repository.lastCatalogBranchId, 'b1');

      cubit.dismissReceipt();
      expect(cubit.state.lastReceipt, isNull);
    });

    test(
      'checkout guards an empty cart and a missing payment method',
      () async {
        final repository = _FakePosRepository()
          ..catalog = _catalog(payments: const <PosPaymentMethod>[]);
        final cubit = _createCubit(repository);
        await cubit.load();

        expect(cubit.state.selectedPaymentMethod, isNull);
        expect(await cubit.placeOrder(), PosCheckoutOutcome.emptyCart);

        cubit.addToCart(cubit.state.productById('p-latte')!);
        expect(cubit.state.canCheckout, isFalse);
        expect(cubit.state.checkoutBlocker, PosCheckoutBlocker.paymentMissing);
        expect(await cubit.placeOrder(), PosCheckoutOutcome.paymentMissing);

        cubit.selectPaymentMode(PosPaymentMode.cash);
        expect(cubit.state.selectedPaymentMethod, isNull);
        expect(repository.orderCalls, 0);
      },
    );

    test('a table is optional and a sale can still be assigned one', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();

      cubit.addToCart(cubit.state.productById('p-latte')!);
      expect(cubit.state.checkoutBlocker, isNull);
      expect(cubit.state.canCheckout, isTrue);

      cubit.selectTable(_table(id: 't-locked', name: 'طاولة مقفولة'));
      expect(cubit.state.selectedTableId, isNull);
      expect(cubit.state.canCheckout, isTrue);

      expect(await cubit.placeOrder(), PosCheckoutOutcome.success);
      expect(repository.orderCalls, 1);
      expect(repository.lastTableId, isNull);
      expect(repository.lastFulfillment, 'dine_in');
      await _settle();

      cubit.addToCart(cubit.state.productById('p-latte')!);
      _selectFirstTable(cubit);
      expect(cubit.state.selectedTable?.name, 'طاولة 1');
      expect(cubit.state.canCheckout, isTrue);

      expect(await cubit.placeOrder(), PosCheckoutOutcome.success);
      expect(repository.lastTableId, 't-1');
      expect(repository.lastFulfillment, 'dine_in');
    });

    test(
      'a second checkout while sending is rejected and locks the cart',
      () async {
        final repository = _FakePosRepository();
        final cubit = _createCubit(repository);
        await cubit.load();
        cubit.addToCart(cubit.state.productById('p-latte')!);
        _selectFirstTable(cubit);
        final key = cubit.state.cart.single.key;

        repository.orderGate = Completer<void>();
        final pending = cubit.placeOrder();
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.isPlacingOrder, isTrue);
        expect(cubit.state.canCheckout, isFalse);
        expect(cubit.addToCart(cubit.state.productById('p-latte')!), isFalse);
        expect(cubit.incrementLine(key), isFalse);
        expect(cubit.removeLine(key), isFalse);
        expect(cubit.clearCart(), isFalse);
        expect(await cubit.placeOrder(), PosCheckoutOutcome.busy);
        expect(repository.orderCalls, 1);

        cubit.selectTable(cubit.state.tableById('t-2'));
        cubit.setOrderNote('later');
        cubit.selectPaymentMode(PosPaymentMode.card);
        await cubit.setBranch('b2');
        expect(cubit.state.selectedTableId, 't-1');
        expect(cubit.state.orderNote, isEmpty);
        expect(cubit.state.paymentMode, PosPaymentMode.cash);
        expect(cubit.state.branchId, 'b1');
        expect(repository.catalogCalls, 1);

        repository.orderGate!.complete();
        expect(await pending, PosCheckoutOutcome.success);
        await _settle();
      },
    );

    test('failures map to outcomes and keep the same attempt key', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();
      cubit.addToCart(cubit.state.productById('p-latte')!);
      _selectFirstTable(cubit);

      const cases = <PosCheckoutFailure, PosCheckoutOutcome>{
        PosCheckoutFailure.permissionDenied:
            PosCheckoutOutcome.permissionDenied,
        PosCheckoutFailure.stockUnavailable:
            PosCheckoutOutcome.stockUnavailable,
        PosCheckoutFailure.productUnavailable:
            PosCheckoutOutcome.productUnavailable,
        PosCheckoutFailure.branchUnavailable:
            PosCheckoutOutcome.branchUnavailable,
        PosCheckoutFailure.paymentUnavailable:
            PosCheckoutOutcome.paymentUnavailable,
        PosCheckoutFailure.customerUnavailable:
            PosCheckoutOutcome.customerUnavailable,
        PosCheckoutFailure.invalid: PosCheckoutOutcome.invalid,
        PosCheckoutFailure.failed: PosCheckoutOutcome.failed,
      };

      for (final entry in cases.entries) {
        repository.checkoutError = PosCheckoutException(entry.key, 'nope');
        expect(await cubit.placeOrder(), entry.value);
        expect(cubit.state.cart, hasLength(1));
        expect(cubit.state.isPlacingOrder, isFalse);
        expect(cubit.state.lastReceipt, isNull);
      }

      expect(repository.keys, hasLength(cases.length));
      expect(repository.keys.toSet(), {'key-1'});

      repository.checkoutError = null;
      expect(await cubit.placeOrder(), PosCheckoutOutcome.success);
      expect(repository.keys.last, 'key-1');
      expect(cubit.state.cart, isEmpty);
      await _settle();
    });

    test('a conflict discards the attempt key before the retry', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();
      cubit.addToCart(cubit.state.productById('p-latte')!);
      _selectFirstTable(cubit);

      repository.checkoutError = const PosCheckoutException(
        PosCheckoutFailure.conflict,
      );
      expect(await cubit.placeOrder(), PosCheckoutOutcome.conflict);
      expect(repository.keys, ['key-1']);

      repository.checkoutError = null;
      expect(await cubit.placeOrder(), PosCheckoutOutcome.success);
      expect(repository.keys, ['key-1', 'key-2']);
      await _settle();
    });

    test('editing the cart after a failure starts a new attempt key', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();
      cubit.addToCart(cubit.state.productById('p-latte')!);
      _selectFirstTable(cubit);

      repository.checkoutError = const PosCheckoutException(
        PosCheckoutFailure.failed,
      );
      await cubit.placeOrder();
      expect(repository.keys, ['key-1']);

      cubit.incrementLine(cubit.state.cart.single.key);
      repository.checkoutError = null;
      expect(await cubit.placeOrder(), PosCheckoutOutcome.success);
      expect(repository.keys, ['key-1', 'key-2']);
      await _settle();
    });
  });

  group('PosCubit split payments', () {
    test(
      'a split sale sends both tenders and resets the cash portion',
      () async {
        final repository = _FakePosRepository();
        final cubit = _createCubit(repository);
        await cubit.load();
        cubit.addToCart(cubit.state.productById('p-latte')!, quantity: 2);
        _selectFirstTable(cubit);

        expect(cubit.state.cartTotal, 46);
        expect(cubit.state.canSplitPayment, isTrue);

        cubit.selectPaymentMode(PosPaymentMode.split);
        expect(cubit.state.paymentMode, PosPaymentMode.split);
        expect(cubit.state.paymentReady, isFalse);
        expect(cubit.state.checkoutBlocker, PosCheckoutBlocker.paymentInvalid);
        expect(await cubit.placeOrder(), PosCheckoutOutcome.paymentInvalid);
        expect(repository.orderCalls, 0);

        cubit.setSplitCash(30);
        expect(cubit.state.splitCashAmount, 30);
        expect(cubit.state.splitCardAmount, 16);
        expect(cubit.state.selectedPaymentMethod?.id, 'pay-cash');
        expect(cubit.state.paymentReady, isTrue);

        cubit.setSplitCash(100);
        expect(cubit.state.splitCashAmount, 100);
        expect(cubit.state.splitCardAmount, 0);
        expect(cubit.state.paymentReady, isFalse);
        expect(await cubit.placeOrder(), PosCheckoutOutcome.paymentInvalid);
        expect(repository.orderCalls, 0);

        cubit.setSplitCash(10);
        expect(cubit.state.splitCashAmount, 10);
        expect(cubit.state.splitCardAmount, 36);
        expect(cubit.state.selectedPaymentMethod?.id, 'pay-card');
        expect(cubit.state.paymentReady, isTrue);

        expect(await cubit.placeOrder(), PosCheckoutOutcome.success);
        expect(repository.lastPaymentMethodId, 'pay-card');
        expect(repository.lastPayments, [
          {'method_id': 'pay-cash', 'amount': 10.0},
          {'method_id': 'pay-card', 'amount': 36.0},
        ]);
        expect(cubit.state.paymentMode, PosPaymentMode.split);
        expect(cubit.state.splitCash, 0);
        await _settle();
      },
    );

    test('cash wins the tie when both portions are equal', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();
      cubit.addToCart(cubit.state.productById('p-latte')!, quantity: 2);
      _selectFirstTable(cubit);
      cubit.selectPaymentMode(PosPaymentMode.split);
      cubit.setSplitCash(23);

      expect(cubit.state.splitCashAmount, 23);
      expect(cubit.state.splitCardAmount, 23);
      expect(cubit.state.selectedPaymentMethod?.id, 'pay-cash');
      expect(await cubit.placeOrder(), PosCheckoutOutcome.success);
      expect(repository.lastPaymentMethodId, 'pay-cash');
      expect(repository.lastPayments, [
        {'method_id': 'pay-cash', 'amount': 23.0},
        {'method_id': 'pay-card', 'amount': 23.0},
      ]);
      await _settle();
    });

    test('editing the card portion derives the cash remainder', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();
      cubit.addToCart(cubit.state.productById('p-latte')!, quantity: 2);
      _selectFirstTable(cubit);
      cubit.selectPaymentMode(PosPaymentMode.split);

      cubit.setSplitCard(16);
      expect(cubit.state.splitCashAmount, 30);
      expect(cubit.state.splitCardAmount, 16);
      expect(cubit.state.paymentReady, isTrue);
      expect(cubit.state.selectedPaymentMethod?.id, 'pay-cash');

      cubit.setSplitCard(40);
      expect(cubit.state.splitCashAmount, 6);
      expect(cubit.state.splitCardAmount, 40);
      expect(cubit.state.selectedPaymentMethod?.id, 'pay-card');

      cubit.setSplitCard(100);
      expect(cubit.state.splitCashAmount, 0);
      expect(cubit.state.splitCardAmount, 46);
      expect(cubit.state.paymentReady, isFalse);
      expect(cubit.state.checkoutBlocker, PosCheckoutBlocker.paymentInvalid);

      cubit.setSplitCard(-5);
      expect(cubit.state.splitCashAmount, 46);
      expect(cubit.state.splitCardAmount, 0);

      cubit.setSplitCard(20);
      expect(cubit.state.paymentReady, isTrue);
      expect(await cubit.placeOrder(), PosCheckoutOutcome.success);
      expect(repository.lastPayments, [
        {'method_id': 'pay-cash', 'amount': 26.0},
        {'method_id': 'pay-card', 'amount': 20.0},
      ]);
      await _settle();
    });

    test('a cash-only menu refuses split and sends a single tender', () async {
      final repository = _FakePosRepository()
        ..catalog = _catalog(
          payments: const [PosPaymentMethod(id: 'pay-cash', code: 'cash')],
        );
      final cubit = _createCubit(repository);
      await cubit.load();
      cubit.addToCart(cubit.state.productById('p-latte')!);
      _selectFirstTable(cubit);

      cubit.selectPaymentMode(PosPaymentMode.split);
      expect(cubit.state.paymentMode, PosPaymentMode.cash);
      expect(cubit.state.canSplitPayment, isFalse);
      expect(cubit.state.selectedPaymentMethod?.id, 'pay-cash');

      expect(await cubit.placeOrder(), PosCheckoutOutcome.success);
      expect(repository.lastPayments, isNull);
      await _settle();
    });

    test('a refresh drops split when the card method disappears', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();
      cubit.addToCart(cubit.state.productById('p-latte')!);
      cubit.selectPaymentMode(PosPaymentMode.split);
      cubit.setSplitCash(10);
      expect(cubit.state.paymentReady, isTrue);

      repository.catalog = _catalog(
        payments: const [PosPaymentMethod(id: 'pay-cash', code: 'cash')],
      );
      await cubit.refresh();

      expect(cubit.state.paymentMode, PosPaymentMode.cash);
      expect(cubit.state.splitCash, 0);
      expect(cubit.state.selectedPaymentMethod?.id, 'pay-cash');
    });
  });

  group('PosCubit reconciliation', () {
    test('a refresh trims the cart to the new menu and stock', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();

      cubit.addToCart(cubit.state.productById('p-latte')!, quantity: 5);
      cubit.addToCart(cubit.state.productById('p-tea')!);
      cubit.addToCart(
        cubit.state.productById('p-mocha')!,
        options: const [_small],
      );
      cubit.setCategory('special');
      cubit.selectPaymentMode(PosPaymentMode.card);
      expect(cubit.state.cart, hasLength(3));

      repository.catalog = _catalog(
        products: [
          _latte(stock: 2),
          _mocha(
            groups: const [
              PosOptionGroup(
                id: 'g-size',
                nameAr: 'الحجم',
                nameEn: 'Size',
                selectionType: PosSelectionType.single,
                isRequired: true,
                values: [
                  PosOptionValue(
                    id: 'v-large',
                    nameAr: 'كبير',
                    nameEn: 'Large',
                    priceDelta: 5,
                  ),
                ],
              ),
            ],
          ),
        ],
        categories: const [
          PosCategory(id: 'coffee', nameAr: 'قهوة', nameEn: 'Coffee'),
        ],
        payments: const [
          PosPaymentMethod(
            id: 'pay-card',
            code: 'card',
            nameAr: 'بطاقة',
            nameEn: 'Card',
          ),
        ],
      );

      await cubit.refresh();

      expect(cubit.state.products.map((product) => product.id), [
        'p-latte',
        'p-mocha',
      ]);
      expect(cubit.state.cart, hasLength(1));
      final line = cubit.state.cart.single;
      expect(line.product.id, 'p-latte');
      expect(line.quantity, 2);
      expect(line.product.stockQuantity, 2);
      expect(cubit.state.categoryId, isNull);
      expect(cubit.state.paymentMode, PosPaymentMode.card);
      expect(cubit.state.selectedPaymentMethod?.id, 'pay-card');
    });

    test('a refresh drops products that are no longer sellable', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();

      cubit.addToCart(cubit.state.productById('p-latte')!);
      expect(cubit.state.cart, hasLength(1));

      repository.catalog = _catalog(
        products: [_latte(available: false), _tea, _mocha()],
      );

      await cubit.refresh();

      expect(cubit.state.cart, isEmpty);
      expect(cubit.state.products, hasLength(3));
    });

    test('holding an order parks the basket and resuming swaps with an active cart', () async {
      final repository = _FakePosRepository();
      final cubit = _createCubit(repository);
      await cubit.load();

      cubit.addToCart(cubit.state.productById('p-latte')!, quantity: 2);
      cubit.selectCustomer(
        const PosCustomer(id: 'c-1', fullName: 'أحمد', phone: '0500000000'),
      );
      cubit.setOrderNote('بدون سكر');
      cubit.setCashReceived(100);

      expect(cubit.holdCurrentOrder(), isTrue);
      expect(cubit.state.cart, isEmpty);
      expect(cubit.state.customer, isNull);
      expect(cubit.state.orderNote, isEmpty);
      expect(cubit.state.cashReceived, 0);
      expect(cubit.state.heldOrders, hasLength(1));

      final firstHeldId = cubit.state.heldOrders.single.id;
      expect(cubit.state.heldOrders.single.quantity, 2);

      // Start a second order while the first is on hold.
      cubit.addToCart(cubit.state.productById('p-tea')!);
      expect(cubit.state.cart.single.product.id, 'p-tea');

      // Resume the first order; the second order is automatically held.
      expect(cubit.resumeHeldOrder(firstHeldId), isTrue);
      expect(cubit.state.cart.single.product.id, 'p-latte');
      expect(cubit.state.cart.single.quantity, 2);
      expect(cubit.state.customer?.fullName, 'أحمد');
      expect(cubit.state.orderNote, 'بدون سكر');
      expect(cubit.state.cashReceivedAmount, 100);
      expect(cubit.state.heldOrders, hasLength(1));
      expect(cubit.state.heldOrders.single.cart.single.product.id, 'p-tea');
    });

    test('cash received calculates change due and remaining due', () async {
      final repository = _FakePosRepository();
      repository.catalog = _catalog(
        taxIncluded: true,
        products: [
          const PosProduct(
            id: 'p-38',
            categoryId: 'coffee',
            nameAr: 'طلب',
            nameEn: 'Order',
            unitPrice: 38,
          ),
        ],
      );
      final cubit = _createCubit(repository);
      await cubit.load();

      cubit.addToCart(cubit.state.productById('p-38')!);
      expect(cubit.state.cartTotal, 38);

      cubit.setCashReceived(100);
      expect(cubit.state.cashChangeDue, 62);
      expect(cubit.state.cashRemainingDue, 0);

      cubit.setCashReceived(200);
      expect(cubit.state.cashChangeDue, 162);

      cubit.setCashReceived(20);
      expect(cubit.state.cashChangeDue, 0);
      expect(cubit.state.cashRemainingDue, 18);
    });
  });
}
