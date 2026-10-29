import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/pos/domain/entities/pos_cart.dart';
import 'package:admin_app/features/pos/domain/entities/pos_catalog.dart';
import 'package:admin_app/features/pos/domain/entities/pos_cashier.dart';
import 'package:admin_app/features/pos/domain/entities/pos_customer.dart';
import 'package:admin_app/features/pos/domain/entities/pos_receipt.dart';
import 'package:admin_app/features/pos/domain/entities/pos_shift.dart';
import 'package:admin_app/features/pos/domain/entities/pos_table.dart';
import 'package:admin_app/features/pos/di/pos_dependencies.dart';
import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/domain/usecases/close_shift.dart';
import 'package:admin_app/features/pos/domain/usecases/create_customer.dart';
import 'package:admin_app/features/pos/domain/usecases/load_catalog.dart';
import 'package:admin_app/features/pos/domain/usecases/load_cashiers.dart';
import 'package:admin_app/features/pos/domain/usecases/load_open_shift.dart';
import 'package:admin_app/features/pos/domain/usecases/load_shift_detail.dart';
import 'package:admin_app/features/pos/domain/usecases/load_shift_history.dart';
import 'package:admin_app/features/pos/domain/usecases/load_tables.dart';
import 'package:admin_app/features/pos/domain/usecases/open_shift.dart';
import 'package:admin_app/features/pos/domain/usecases/place_order.dart';
import 'package:admin_app/features/pos/domain/usecases/record_cash_movement.dart';
import 'package:admin_app/features/pos/domain/usecases/search_customers.dart';
import 'package:admin_app/features/pos/domain/usecases/seat_reservation.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_state.dart';
import 'package:admin_app/core/models/dining_table.dart';

enum PosCheckoutOutcome {
  success,
  busy,
  emptyCart,
  branchMissing,
  shiftRequired,
  paymentMissing,
  paymentInvalid,
  tableUnavailable,
  permissionDenied,
  stockUnavailable,
  productUnavailable,
  branchUnavailable,
  paymentUnavailable,
  customerUnavailable,
  invalid,
  conflict,
  failed,
}

/// The point-of-sale basket and the counter sale.
class PosCubit extends Cubit<PosState> {
  PosCubit({PosRepository? repository, String Function()? checkoutKeyFactory})
    : this._withUseCases(
        repository ?? PosDependencies.repository,
        checkoutKeyFactory ?? _defaultCheckoutKey,
      );

  PosCubit._withUseCases(
    PosRepository repository,
    String Function() checkoutKeyFactory,
  ) : _loadCatalog = LoadCatalogUseCase(repository),
      _loadTables = LoadTablesUseCase(repository),
      _seatReservation = SeatReservationUseCase(repository),
      _placeOrder = PlaceOrderUseCase(repository),
      _searchCustomers = SearchCustomersUseCase(repository),
      _createCustomer = CreateCustomerUseCase(repository),
      _loadOpenShift = LoadOpenShiftUseCase(repository),
      _openShift = OpenShiftUseCase(repository),
      _recordCashMovement = RecordCashMovementUseCase(repository),
      _closeShift = CloseShiftUseCase(repository),
      _loadShiftHistory = LoadShiftHistoryUseCase(repository),
      _loadShiftDetail = LoadShiftDetailUseCase(repository),
      _loadCashiers = LoadCashiersUseCase(repository),
      _checkoutKeyFactory = checkoutKeyFactory,
      super(const PosState());

  final LoadCatalogUseCase _loadCatalog;
  final LoadTablesUseCase _loadTables;
  final SeatReservationUseCase _seatReservation;
  final PlaceOrderUseCase _placeOrder;
  final SearchCustomersUseCase _searchCustomers;
  final CreateCustomerUseCase _createCustomer;
  final LoadOpenShiftUseCase _loadOpenShift;
  final OpenShiftUseCase _openShift;
  final RecordCashMovementUseCase _recordCashMovement;
  final CloseShiftUseCase _closeShift;
  final LoadShiftHistoryUseCase _loadShiftHistory;
  final LoadShiftDetailUseCase _loadShiftDetail;
  final LoadCashiersUseCase _loadCashiers;
  final String Function() _checkoutKeyFactory;

  String? _checkoutKey;
  int _requestId = 0;
  int _tablesRequestId = 0;
  int _customerRequestId = 0;
  int _shiftRequestId = 0;
  int _cashiersRequestId = 0;
  int _heldOrderSequence = 0;

  Future<void> load() async {
    if (state.isLoading) return;
    await _fetch(first: true);
  }

  Future<void> refresh() async {
    if (state.isLoading || state.isRefreshing || state.isSeating) return;
    await _fetch(first: !state.hasData);
  }

  Future<void> setBranch(String branchId) async {
    if (state.isPlacingOrder || branchId == state.branchId) return;
    if (!state.branches.any((branch) => branch.id == branchId)) return;
    _checkoutKey = null;
    _customerRequestId += 1;
    _tablesRequestId += 1;
    _cashiersRequestId += 1;
    emit(
      state.copyWith(
        status: PosStatus.loading,
        branchId: branchId,
        products: const <PosProduct>[],
        categories: const <PosCategory>[],
        paymentMethods: const <PosPaymentMethod>[],
        tables: const <DiningTable>[],
        clearSelectedTable: true,
        clearTablesFailure: true,
        isLoadingTables: false,
        isSeating: false,
        cart: const <PosCartLine>[],
        heldOrders: const <PosHeldOrder>[],
        clearCustomer: true,
        customerResults: const <PosCustomer>[],
        customerQuery: '',
        isSearchingCustomers: false,
        clearCustomerFailure: true,
        orderNote: '',
        clearCategory: true,
        paymentMode: PosPaymentMode.cash,
        splitCash: 0,
        cashReceived: 0,
        isRefreshing: false,
        clearFailure: true,
        clearError: true,
        clearShift: true,
        shiftKnown: false,
        isLoadingShift: false,
        isOpeningShift: false,
        isClosingShift: false,
        isSavingMovement: false,
        clearShiftFailure: true,
        shiftHistory: const <PosShift>[],
        isLoadingShiftHistory: false,
        clearShiftHistoryFailure: true,
        clearShiftDetail: true,
        isLoadingShiftDetail: false,
        cashiers: const <PosCashier>[],
        isLoadingCashiers: false,
        clearCashiersFailure: true,
      ),
    );
    await _fetch(branchId: branchId);
  }

  void updateSearch(String value) {
    final normalized = value.trim();
    if (normalized == state.search) return;
    emit(state.copyWith(search: normalized));
  }

  void setCategory(String? categoryId) {
    if (categoryId == state.categoryId) return;
    if (categoryId == null) {
      emit(state.copyWith(clearCategory: true));
      return;
    }
    if (!state.categories.any((category) => category.id == categoryId)) return;
    emit(state.copyWith(categoryId: categoryId));
  }

  void clearFilters() {
    if (!state.hasActiveFilters) return;
    emit(state.copyWith(search: '', clearCategory: true));
  }

  bool addToCart(
    PosProduct product, {
    List<PosOptionValue> options = const <PosOptionValue>[],
    String note = '',
    int quantity = 1,
  }) {
    if (state.isPlacingOrder) return false;
    final current = state.productById(product.id);
    if (current == null || !current.isSellable) return false;

    final selected = _validatedOptions(current, options);
    if (selected == null) return false;

    final remaining = state.remainingFor(current);
    if (remaining != null && remaining <= 0) return false;

    final trimmedNote = note.trim();
    final key = PosCartLine.cartKey(
      productId: current.id,
      optionIds: [for (final option in selected) option.id],
      note: trimmedNote,
    );
    final lines = List<PosCartLine>.of(state.cart);
    final index = lines.indexWhere((line) => line.key == key);
    var requested = max(quantity, 1);
    if (remaining != null) requested = min(requested, remaining);
    if (requested <= 0) return false;

    if (index >= 0) {
      final line = lines[index];
      final nextQuantity = min(line.quantity + requested, 99);
      if (nextQuantity == line.quantity) return false;
      lines[index] = line.copyWith(quantity: nextQuantity);
    } else {
      lines.add(
        PosCartLine(
          product: current,
          options: selected,
          quantity: min(requested, 99),
          note: trimmedNote,
        ),
      );
    }

    _checkoutKey = null;
    emit(state.copyWith(cart: List<PosCartLine>.unmodifiable(lines)));
    return true;
  }

  bool incrementLine(String key) {
    final index = state.cart.indexWhere((line) => line.key == key);
    if (index < 0) return false;
    return setLineQuantity(key, state.cart[index].quantity + 1);
  }

  bool decrementLine(String key) {
    final index = state.cart.indexWhere((line) => line.key == key);
    if (index < 0) return false;
    final quantity = state.cart[index].quantity;
    if (quantity <= 1) return removeLine(key);
    return setLineQuantity(key, quantity - 1);
  }

  bool setLineQuantity(String key, int quantity) {
    if (state.isPlacingOrder) return false;
    final index = state.cart.indexWhere((line) => line.key == key);
    if (index < 0) return false;
    if (quantity <= 0) return removeLine(key);

    final line = state.cart[index];
    var next = min(quantity, 99);
    final limit = line.product.stockLimit;
    if (limit != null) {
      final others = state.quantityOf(line.product.id) - line.quantity;
      final cap = limit - others;
      if (cap <= 0) return false;
      next = min(next, cap);
    }
    if (next == line.quantity) return false;

    final lines = List<PosCartLine>.of(state.cart);
    lines[index] = line.copyWith(quantity: next);
    _checkoutKey = null;
    emit(state.copyWith(cart: List<PosCartLine>.unmodifiable(lines)));
    return true;
  }

  bool removeLine(String key) {
    if (state.isPlacingOrder) return false;
    final lines = state.cart
        .where((line) => line.key != key)
        .toList(growable: false);
    if (lines.length == state.cart.length) return false;
    _checkoutKey = null;
    emit(state.copyWith(cart: lines));
    return true;
  }

  bool clearCart() {
    if (state.isPlacingOrder || state.cart.isEmpty) return false;
    _checkoutKey = null;
    emit(state.copyWith(cart: const <PosCartLine>[], cashReceived: 0));
    return true;
  }

  /// Parks the active basket so the cashier can serve another guest and return
  /// to this order later.
  bool holdCurrentOrder() {
    if (state.isPlacingOrder || state.cart.isEmpty) return false;
    final held = _snapshotCurrentOrder();
    _checkoutKey = null;
    _customerRequestId += 1;
    emit(
      state.copyWith(
        heldOrders: List<PosHeldOrder>.unmodifiable([
          held,
          ...state.heldOrders,
        ]),
        cart: const <PosCartLine>[],
        clearCustomer: true,
        customerResults: const <PosCustomer>[],
        customerQuery: '',
        isSearchingCustomers: false,
        clearCustomerFailure: true,
        clearSelectedTable: true,
        orderNote: '',
        splitCash: 0,
        cashReceived: 0,
      ),
    );
    return true;
  }

  /// Restores a held order into the active basket. When the active basket has
  /// items, it is parked first so no work is lost.
  bool resumeHeldOrder(String heldOrderId) {
    if (state.isPlacingOrder) return false;
    final index = state.heldOrders.indexWhere((item) => item.id == heldOrderId);
    if (index < 0) return false;

    final target = state.heldOrders[index];
    final remainingHeld = <PosHeldOrder>[
      if (state.cart.isNotEmpty) _snapshotCurrentOrder(),
      for (var i = 0; i < state.heldOrders.length; i++)
        if (i != index) state.heldOrders[i],
    ];

    final selectedTable = target.tableId == null
        ? null
        : state.tableById(target.tableId!);
    final keepTable = selectedTable != null && selectedTable.isPosSelectable;

    final paymentMode = switch (target.paymentMode) {
      PosPaymentMode.split when state.canSplitPayment => PosPaymentMode.split,
      PosPaymentMode.card when state.cardMethod != null => PosPaymentMode.card,
      PosPaymentMode.cash when state.cashMethod != null => PosPaymentMode.cash,
      _ => state.paymentMode,
    };

    _checkoutKey = null;
    _customerRequestId += 1;
    emit(
      state.copyWith(
        heldOrders: List<PosHeldOrder>.unmodifiable(remainingHeld),
        cart: List<PosCartLine>.unmodifiable(target.cart),
        customer: target.customer,
        clearCustomer: target.customer == null,
        customerResults: const <PosCustomer>[],
        customerQuery: '',
        isSearchingCustomers: false,
        clearCustomerFailure: true,
        selectedTableId: keepTable ? selectedTable.id : null,
        clearSelectedTable: !keepTable,
        orderNote: target.orderNote,
        paymentMode: paymentMode,
        splitCash: paymentMode == PosPaymentMode.split ? target.splitCash : 0,
        cashReceived: target.cashReceived,
      ),
    );
    return true;
  }

  bool discardHeldOrder(String heldOrderId) {
    if (state.isPlacingOrder) return false;
    final next = state.heldOrders
        .where((item) => item.id != heldOrderId)
        .toList(growable: false);
    if (next.length == state.heldOrders.length) return false;
    emit(state.copyWith(heldOrders: List<PosHeldOrder>.unmodifiable(next)));
    return true;
  }

  PosHeldOrder _snapshotCurrentOrder() {
    final number = ++_heldOrderSequence;
    return PosHeldOrder(
      id: 'hold-$number-${DateTime.now().microsecondsSinceEpoch}',
      number: number,
      heldAt: DateTime.now(),
      cart: state.cart,
      customer: state.customer,
      tableId: state.selectedTableId,
      tableName: state.selectedTable?.name,
      orderNote: state.orderNote,
      paymentMode: state.paymentMode,
      splitCash: state.splitCash,
      cashReceived: state.cashReceived,
    );
  }

  void selectTable(DiningTable? table) {
    if (state.isPlacingOrder || state.isSeating) return;
    if (table == null) {
      if (state.selectedTableId == null) return;
      _checkoutKey = null;
      emit(state.copyWith(clearSelectedTable: true));
      return;
    }
    final current = state.tableById(table.id);
    if (current == null || !current.isPosSelectable) return;
    if (current.id == state.selectedTableId) return;
    _checkoutKey = null;
    emit(state.copyWith(selectedTableId: current.id));
  }

  Future<void> refreshTables() async {
    if (state.isPlacingOrder || state.isSeating || state.isLoadingTables) {
      return;
    }
    await _reloadTables(state.branchId);
  }

  /// Marks the booked guest as seated, reloads the floor and selects the table
  /// so the cashier can place their order right away.
  Future<PosSeatOutcome> seatReservation(DiningTable table) async {
    if (state.isPlacingOrder || state.isSeating || state.isLoadingTables) {
      return PosSeatOutcome.failed;
    }
    final current = state.tableById(table.id);
    final reservation = current?.reservation;
    if (current == null || reservation == null || !current.canSeatGuest) {
      return PosSeatOutcome.invalidStatus;
    }

    emit(state.copyWith(isSeating: true));
    final outcome = await _seatReservation(reservation.id);
    if (isClosed) return outcome;
    emit(state.copyWith(isSeating: false));
    if (outcome != PosSeatOutcome.success) return outcome;

    await _reloadTables(state.branchId);
    if (isClosed) return outcome;
    final refreshed = state.tableById(table.id);
    if (refreshed != null && refreshed.isPosSelectable) {
      _checkoutKey = null;
      emit(state.copyWith(selectedTableId: refreshed.id));
    }
    return outcome;
  }

  Future<void> _reloadTables(String? branchId) async {
    if (branchId == null || branchId.isEmpty || state.isPlacingOrder) return;
    final request = ++_tablesRequestId;
    emit(state.copyWith(isLoadingTables: true, clearTablesFailure: true));
    try {
      final tables = await _loadTables(branchId);
      if (isClosed || request != _tablesRequestId) return;
      if (state.branchId != branchId) return;
      _publishTables(tables);
    } on PosTablesException catch (error) {
      _failTables(request, error.failure);
    } catch (_) {
      _failTables(request, PosTablesFailure.failed);
    }
  }

  void _publishTables(List<DiningTable> tables) {
    final id = state.selectedTableId;
    final selected = id == null ? null : _tableIn(tables, id);
    final keep = selected != null && selected.isPosSelectable;
    if (!keep) _checkoutKey = null;
    emit(
      state.copyWith(
        tables: tables,
        isLoadingTables: false,
        clearTablesFailure: true,
        selectedTableId: keep ? selected.id : null,
        clearSelectedTable: !keep,
      ),
    );
  }

  void _failTables(int request, PosTablesFailure failure) {
    if (isClosed || request != _tablesRequestId) return;
    emit(state.copyWith(isLoadingTables: false, tablesFailure: failure));
  }

  DiningTable? _tableIn(List<DiningTable> tables, String id) {
    for (final table in tables) {
      if (table.id == id) return table;
    }
    return null;
  }

  /// Loads the customer picker list. The query is trimmed; an empty query
  /// returns the most recent customers so the cashier can pick quickly.
  Future<void> searchCustomers(String query) async {
    final normalized = query.trim();
    final request = ++_customerRequestId;
    emit(
      state.copyWith(
        customerQuery: normalized,
        isSearchingCustomers: true,
        clearCustomerFailure: true,
      ),
    );

    try {
      final customers = await _searchCustomers(query: normalized);
      if (isClosed || request != _customerRequestId) return;
      emit(
        state.copyWith(
          customerResults: List<PosCustomer>.unmodifiable(customers),
          isSearchingCustomers: false,
          clearCustomerFailure: true,
        ),
      );
    } on PosCustomerException catch (error) {
      _failCustomerSearch(request, error.failure);
    } catch (_) {
      _failCustomerSearch(request, PosCustomerFailure.failed);
    }
  }

  Future<PosCustomer?> createCustomer({
    required String fullName,
    String phone = '',
    String email = '',
    String note = '',
  }) async {
    if (state.isPlacingOrder || state.isCreatingCustomer) return null;

    emit(state.copyWith(isCreatingCustomer: true, clearCustomerFailure: true));

    try {
      final customer = await _createCustomer(
        fullName: fullName,
        phone: phone,
        email: email,
        note: note,
      );
      if (isClosed) return null;

      _checkoutKey = null;
      final others = state.customerResults.where(
        (item) => item.id != customer.id,
      );
      _customerRequestId += 1;
      emit(
        state.copyWith(
          isCreatingCustomer: false,
          customer: customer,
          customerResults: List<PosCustomer>.unmodifiable([
            customer,
            ...others,
          ]),
          customerQuery: '',
          isSearchingCustomers: false,
          clearCustomerFailure: true,
        ),
      );
      return customer;
    } on PosCustomerException catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isCreatingCustomer: false,
            customerFailure: error.failure,
          ),
        );
      }
      return null;
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isCreatingCustomer: false,
            customerFailure: PosCustomerFailure.failed,
          ),
        );
      }
      return null;
    }
  }

  void selectCustomer(PosCustomer? customer) {
    if (state.isPlacingOrder) return;
    if (customer == null) {
      if (state.customer == null) return;
      _checkoutKey = null;
      emit(state.copyWith(clearCustomer: true));
      return;
    }
    if (customer.id == state.customer?.id &&
        customer.source == state.customer?.source) {
      return;
    }
    _checkoutKey = null;
    emit(state.copyWith(customer: customer, clearCustomerFailure: true));
  }

  void resetCustomerSearch() {
    if (!state.hasCustomerSearch) return;
    _customerRequestId += 1;
    emit(
      state.copyWith(
        customerResults: const <PosCustomer>[],
        customerQuery: '',
        isSearchingCustomers: false,
        clearCustomerFailure: true,
      ),
    );
  }

  void _failCustomerSearch(int request, PosCustomerFailure failure) {
    if (isClosed || request != _customerRequestId) return;
    emit(state.copyWith(isSearchingCustomers: false, customerFailure: failure));
  }

  void setOrderNote(String value) {
    if (state.isPlacingOrder || value == state.orderNote) return;
    _checkoutKey = null;
    emit(state.copyWith(orderNote: value));
  }

  void selectPaymentMode(PosPaymentMode mode) {
    if (state.isPlacingOrder || mode == state.paymentMode) return;
    final available = switch (mode) {
      PosPaymentMode.cash => state.cashMethod != null,
      PosPaymentMode.card => state.cardMethod != null,
      PosPaymentMode.split => state.canSplitPayment,
    };
    if (!available) return;
    _checkoutKey = null;
    emit(
      state.copyWith(
        paymentMode: mode,
        splitCash: 0,
        cashReceived: mode == PosPaymentMode.card ? 0 : state.cashReceived,
      ),
    );
  }

  /// Records the cash amount handed over by the customer to calculate change.
  void setCashReceived(double value) {
    if (state.isPlacingOrder) return;
    final normalized = value.isFinite && value > 0 ? posRound2(value) : 0.0;
    if (normalized == state.cashReceived) return;
    emit(state.copyWith(cashReceived: normalized));
  }

  /// Records the cash portion of a split payment; the remainder goes on card.
  void setSplitCash(double value) {
    if (state.isPlacingOrder || state.paymentMode != PosPaymentMode.split) {
      return;
    }
    final normalized = value.isFinite && value > 0 ? value : 0.0;
    if (normalized == state.splitCash) return;
    _checkoutKey = null;
    emit(state.copyWith(splitCash: normalized));
  }

  /// Records the card portion of a split payment; the remainder is cash.
  /// The amount is capped at the order total so the two fields always balance.
  void setSplitCard(double value) {
    if (state.isPlacingOrder || state.paymentMode != PosPaymentMode.split) {
      return;
    }
    final total = state.cartTotal;
    if (total <= 0) return;
    final card = value.isFinite && value > 0
        ? min(posRound2(value), total)
        : 0.0;
    final cash = posRound2(total - card);
    if (cash == state.splitCash) return;
    _checkoutKey = null;
    emit(state.copyWith(splitCash: cash));
  }

  /// A single tender is covered by the primary method; a split sale must send
  /// both allocations so the server can capture one row per method.
  List<Map<String, Object?>>? _tenderPayments() {
    if (state.paymentMode != PosPaymentMode.split) return null;
    final cash = state.cashMethod;
    final card = state.cardMethod;
    if (cash == null || card == null) return null;
    return <Map<String, Object?>>[
      {'method_id': cash.id, 'amount': state.splitCashAmount},
      {'method_id': card.id, 'amount': state.splitCardAmount},
    ];
  }

  Future<PosCheckoutOutcome> placeOrder() async {
    if (state.isPlacingOrder) return PosCheckoutOutcome.busy;
    if (state.cart.isEmpty) return PosCheckoutOutcome.emptyCart;

    final branchId = state.branchId;
    if (branchId == null || branchId.isEmpty) {
      return PosCheckoutOutcome.branchMissing;
    }
    if (state.shiftMissing) return PosCheckoutOutcome.shiftRequired;
    final payment = state.selectedPaymentMethod;
    if (!state.paymentReady || payment == null) {
      return state.paymentMode == PosPaymentMode.split
          ? PosCheckoutOutcome.paymentInvalid
          : PosCheckoutOutcome.paymentMissing;
    }

    final table = state.selectedTable;
    if (table != null && !table.isPosSelectable) {
      return PosCheckoutOutcome.tableUnavailable;
    }

    final key = _checkoutKey ??= _checkoutKeyFactory();
    final payments = _tenderPayments();
    final lines = <Map<String, Object?>>[
      for (final line in state.cart)
        <String, Object?>{
          'product_id': line.product.id,
          'quantity': line.quantity,
          if (line.note.trim().isNotEmpty) 'note': line.note.trim(),
          if (line.options.isNotEmpty)
            'option_value_ids': [for (final option in line.options) option.id],
        },
    ];

    emit(state.copyWith(isPlacingOrder: true, clearError: true));
    try {
      final result = await _placeOrder(
        branchId: branchId,
        lines: lines,
        fulfillmentType: PosFulfillmentType.dineIn.value,
        paymentMethodId: payment.id,
        idempotencyKey: key,
        tableId: table?.id,
        note: state.orderNote,
        customerId: state.customer?.id,
        payments: payments,
      );
      if (isClosed) return PosCheckoutOutcome.success;

      _checkoutKey = null;
      _customerRequestId += 1;
      final receipt = PosReceipt(
        result: result,
        lines: List<PosCartLine>.unmodifiable(state.cart),
        note: state.orderNote,
      );
      emit(
        state.copyWith(
          isPlacingOrder: false,
          cart: const <PosCartLine>[],
          clearCustomer: true,
          customerResults: const <PosCustomer>[],
          customerQuery: '',
          isSearchingCustomers: false,
          clearCustomerFailure: true,
          clearSelectedTable: true,
          orderNote: '',
          splitCash: 0,
          cashReceived: 0,
          lastReceipt: receipt,
          clearError: true,
        ),
      );
      // The receipt opens right away; the menu refresh runs in the background.
      unawaited(_fetch());
      return PosCheckoutOutcome.success;
    } on PosCheckoutException catch (error) {
      if (kDebugMode) {
        debugPrint('[POS] checkout rejected: ${error.failure.name}');
        if (error.message != null && error.message!.isNotEmpty) {
          debugPrint('[POS] checkout message: ${error.message}');
        }
      }
      if (error.failure == PosCheckoutFailure.conflict) {
        _checkoutKey = null;
      }
      final tableLost = error.failure == PosCheckoutFailure.tableUnavailable;
      final shiftLost = error.failure == PosCheckoutFailure.shiftRequired;
      if (!isClosed) {
        emit(
          state.copyWith(
            isPlacingOrder: false,
            clearSelectedTable: tableLost,
            clearShift: shiftLost,
            shiftKnown: shiftLost ? true : null,
          ),
        );
        if (tableLost) unawaited(refreshTables());
      }
      return switch (error.failure) {
        PosCheckoutFailure.permissionDenied =>
          PosCheckoutOutcome.permissionDenied,
        PosCheckoutFailure.shiftRequired => PosCheckoutOutcome.shiftRequired,
        PosCheckoutFailure.tableUnavailable =>
          PosCheckoutOutcome.tableUnavailable,
        PosCheckoutFailure.stockUnavailable =>
          PosCheckoutOutcome.stockUnavailable,
        PosCheckoutFailure.productUnavailable =>
          PosCheckoutOutcome.productUnavailable,
        PosCheckoutFailure.branchUnavailable =>
          PosCheckoutOutcome.branchUnavailable,
        PosCheckoutFailure.paymentUnavailable =>
          PosCheckoutOutcome.paymentUnavailable,
        PosCheckoutFailure.customerUnavailable =>
          PosCheckoutOutcome.customerUnavailable,
        PosCheckoutFailure.invalid => PosCheckoutOutcome.invalid,
        PosCheckoutFailure.conflict => PosCheckoutOutcome.conflict,
        PosCheckoutFailure.failed => PosCheckoutOutcome.failed,
      };
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[POS] checkout threw: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!isClosed) {
        emit(state.copyWith(isPlacingOrder: false));
      }
      return PosCheckoutOutcome.failed;
    }
  }

  void dismissReceipt() {
    if (isClosed || state.lastReceipt == null) return;
    emit(state.copyWith(clearLastReceipt: true));
  }

  /// Re-reads the branch drawer after an external change (a sale, a refund in
  /// another terminal, or opening the page on a new day).
  Future<PosShift?> refreshShift() async {
    final branchId = state.branchId;
    if (branchId == null || branchId.isEmpty || state.isLoading) return null;
    final request = ++_shiftRequestId;
    emit(state.copyWith(isLoadingShift: true, clearShiftFailure: true));
    try {
      final shift = await _loadOpenShift(branchId);
      if (isClosed || request != _shiftRequestId) return shift;
      if (state.branchId != branchId) return shift;
      emit(
        state.copyWith(
          shift: shift,
          clearShift: shift == null,
          shiftKnown: true,
          isLoadingShift: false,
          clearShiftFailure: true,
        ),
      );
      return shift;
    } on PosShiftException catch (error) {
      _failShift(request, error.failure);
    } catch (_) {
      _failShift(request, PosShiftFailure.failed);
    }
    return null;
  }

  /// Reads the staff members who may hold the drawer of the selected branch.
  /// The form still opens the shift without them: opening for yourself needs
  /// no candidate list.
  Future<void> loadCashiers() async {
    final branchId = state.branchId;
    if (branchId == null || branchId.isEmpty) return;
    if (state.isLoadingCashiers) return;

    final request = ++_cashiersRequestId;
    emit(state.copyWith(isLoadingCashiers: true, clearCashiersFailure: true));
    try {
      final cashiers = await _loadCashiers(branchId);
      if (isClosed || request != _cashiersRequestId) return;
      emit(
        state.copyWith(
          cashiers: cashiers,
          isLoadingCashiers: false,
          clearCashiersFailure: true,
        ),
      );
    } on PosShiftException catch (error) {
      if (isClosed || request != _cashiersRequestId) return;
      emit(
        state.copyWith(
          cashiers: const <PosCashier>[],
          isLoadingCashiers: false,
          cashiersFailure: error.failure,
        ),
      );
    } catch (_) {
      if (isClosed || request != _cashiersRequestId) return;
      emit(
        state.copyWith(
          cashiers: const <PosCashier>[],
          isLoadingCashiers: false,
          cashiersFailure: PosShiftFailure.failed,
        ),
      );
    }
  }

  /// Opens the branch drawer with a starting float, in the name of the caller
  /// or of a cashier the server accepts for that branch. The server returns
  /// the existing shift when one is already open, so a double tap is harmless
  /// and a live drawer is never reassigned.
  Future<PosShift?> openShift({
    required double openingFloat,
    String note = '',
    String? cashierId,
  }) async {
    final branchId = state.branchId;
    if (branchId == null || branchId.isEmpty || state.isOpeningShift) {
      return null;
    }
    if (!openingFloat.isFinite || openingFloat < 0) return null;

    emit(state.copyWith(isOpeningShift: true, clearShiftFailure: true));
    try {
      final shift = await _openShift(
        branchId: branchId,
        openingFloat: openingFloat,
        note: note,
        cashierId: cashierId,
      );
      if (isClosed) return shift;
      emit(
        state.copyWith(
          shift: shift,
          shiftKnown: true,
          isOpeningShift: false,
          clearShiftFailure: true,
        ),
      );
      return shift;
    } on PosShiftException catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(isOpeningShift: false, shiftFailure: error.failure),
        );
      }
      return null;
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isOpeningShift: false,
            shiftFailure: PosShiftFailure.failed,
          ),
        );
      }
      return null;
    }
  }

  Future<PosShift?> recordCashMovement({
    required PosCashMovementKind kind,
    required double amount,
    required String reason,
  }) async {
    final shift = state.shift;
    if (shift == null || !shift.isOpen || state.isSavingMovement) return null;
    if (!amount.isFinite || amount <= 0 || reason.trim().isEmpty) return null;

    emit(state.copyWith(isSavingMovement: true, clearShiftFailure: true));
    try {
      final updated = await _recordCashMovement(
        shiftId: shift.id,
        kind: kind,
        amount: amount,
        reason: reason,
      );
      if (isClosed) return updated;
      emit(
        state.copyWith(
          shift: updated,
          isSavingMovement: false,
          clearShiftFailure: true,
        ),
      );
      return updated;
    } on PosShiftException catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(isSavingMovement: false, shiftFailure: error.failure),
        );
      }
      return null;
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isSavingMovement: false,
            shiftFailure: PosShiftFailure.failed,
          ),
        );
      }
      return null;
    }
  }

  /// Counts the drawer and closes the shift. The server snapshots the totals
  /// and returns the closed report, which the page shows as its Z receipt.
  Future<PosShift?> closeShift({
    required double countedCash,
    String note = '',
  }) async {
    final shift = state.shift;
    if (shift == null || !shift.isOpen || state.isClosingShift) return null;
    if (!countedCash.isFinite || countedCash < 0) return null;

    emit(state.copyWith(isClosingShift: true, clearShiftFailure: true));
    try {
      final closed = await _closeShift(
        shiftId: shift.id,
        countedCash: countedCash,
        closeNote: note,
      );
      if (isClosed) return closed;
      emit(
        state.copyWith(
          isClosingShift: false,
          clearShift: true,
          shiftKnown: true,
          clearShiftFailure: true,
          shiftHistory: const <PosShift>[],
          clearShiftHistoryFailure: true,
          clearShiftDetail: true,
        ),
      );
      return closed;
    } on PosShiftException catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(isClosingShift: false, shiftFailure: error.failure),
        );
      }
      return null;
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isClosingShift: false,
            shiftFailure: PosShiftFailure.failed,
          ),
        );
      }
      return null;
    }
  }

  Future<void> loadShiftHistory({bool append = false}) async {
    final branchId = state.branchId;
    if (branchId == null || branchId.isEmpty) return;
    if (state.isLoadingShiftHistory) return;

    final offset = append ? state.shiftHistory.length : 0;
    emit(
      state.copyWith(
        isLoadingShiftHistory: true,
        clearShiftHistoryFailure: true,
        shiftHistory: append ? null : const <PosShift>[],
      ),
    );
    try {
      final shifts = await _loadShiftHistory(
        branchId,
        limit: PosState.shiftHistoryPageSize,
        offset: offset,
      );
      if (isClosed || state.branchId != branchId) return;
      final known = {for (final shift in state.shiftHistory) shift.id};
      final merged = append
          ? <PosShift>[
              ...state.shiftHistory,
              ...shifts.where((shift) => !known.contains(shift.id)),
            ]
          : shifts;
      emit(
        state.copyWith(
          shiftHistory: List<PosShift>.unmodifiable(merged),
          isLoadingShiftHistory: false,
          clearShiftHistoryFailure: true,
        ),
      );
    } on PosShiftException catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoadingShiftHistory: false,
            shiftHistoryFailure: error.failure,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoadingShiftHistory: false,
            shiftHistoryFailure: PosShiftFailure.failed,
          ),
        );
      }
    }
  }

  Future<PosShift?> loadShiftDetail(String shiftId) async {
    if (state.isLoadingShiftDetail) return null;
    emit(
      state.copyWith(
        isLoadingShiftDetail: true,
        clearShiftDetail: true,
        clearShiftHistoryFailure: true,
      ),
    );
    try {
      final detail = await _loadShiftDetail(shiftId);
      if (isClosed) return detail;
      emit(
        state.copyWith(
          shiftDetail: detail,
          isLoadingShiftDetail: false,
          clearShiftHistoryFailure: true,
        ),
      );
      return detail;
    } on PosShiftException catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoadingShiftDetail: false,
            shiftHistoryFailure: error.failure,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoadingShiftDetail: false,
            shiftHistoryFailure: PosShiftFailure.failed,
          ),
        );
      }
    }
    return null;
  }

  void clearShiftDetail() {
    if (state.shiftDetail == null && !state.isLoadingShiftDetail) return;
    emit(state.copyWith(clearShiftDetail: true, isLoadingShiftDetail: false));
  }

  void _failShift(int request, PosShiftFailure failure) {
    if (isClosed || request != _shiftRequestId) return;
    emit(state.copyWith(isLoadingShift: false, shiftFailure: failure));
  }

  Future<void> _fetch({bool first = false, String? branchId}) async {
    final request = ++_requestId;
    final tablesRequest = ++_tablesRequestId;
    final target = branchId ?? state.branchId;
    if (first) {
      emit(
        state.copyWith(
          status: PosStatus.loading,
          isRefreshing: false,
          isLoadingTables: true,
          isLoadingShift: true,
          clearFailure: true,
          clearError: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          isRefreshing: true,
          isLoadingTables: true,
          isLoadingShift: true,
          clearError: true,
        ),
      );
    }

    try {
      final catalog = await _loadCatalog(branchId: target);
      if (isClosed || request != _requestId) return;

      final resolvedBranch = catalog.branchId.isNotEmpty
          ? catalog.branchId
          : target;
      final paymentMode = _resolvePaymentMode(catalog.paymentMethods);
      final currentCategory = state.categoryId;
      final categoryExists =
          currentCategory != null &&
          catalog.categories.any((category) => category.id == currentCategory);
      final cart = _reconcileCart(catalog, state.cart);

      var tables = state.tables;
      PosTablesFailure? tablesFailure;
      if (resolvedBranch != null && resolvedBranch.isNotEmpty) {
        try {
          tables = await _loadTables(resolvedBranch);
        } on PosTablesException catch (error) {
          tablesFailure = error.failure;
        } catch (_) {
          tablesFailure = PosTablesFailure.failed;
        }
        if (isClosed ||
            request != _requestId ||
            tablesRequest != _tablesRequestId) {
          return;
        }
      }

      var shift = state.shift;
      var shiftKnown = state.shiftKnown;
      PosShiftFailure? shiftFailure;
      if (resolvedBranch == null || resolvedBranch.isEmpty) {
        shift = null;
        shiftKnown = false;
      } else {
        final shiftRequest = ++_shiftRequestId;
        try {
          shift = await _loadOpenShift(resolvedBranch);
          shiftKnown = true;
        } on PosShiftException catch (error) {
          shiftFailure = error.failure;
        } catch (_) {
          shiftFailure = PosShiftFailure.failed;
        }
        if (isClosed || request != _requestId) return;
        if (shiftRequest != _shiftRequestId) {
          shift = state.shift;
          shiftKnown = state.shiftKnown;
          shiftFailure = state.shiftFailure;
        }
      }

      final selectedId = state.selectedTableId;
      final selected = selectedId == null ? null : _tableIn(tables, selectedId);
      final keepSelection = selected != null && selected.isPosSelectable;
      if (!keepSelection) _checkoutKey = null;

      emit(
        state.copyWith(
          status: PosStatus.ready,
          branches: catalog.branches,
          categories: catalog.categories,
          paymentMethods: catalog.paymentMethods,
          products: catalog.products,
          branchId: resolvedBranch,
          tables: tables,
          tablesFailure: tablesFailure,
          clearTablesFailure: tablesFailure == null,
          selectedTableId: keepSelection ? selected.id : null,
          clearSelectedTable: !keepSelection,
          isLoadingTables: false,
          currencyCode: catalog.currencyCode,
          taxRate: catalog.taxRate,
          taxIncluded: catalog.taxIncluded,
          categoryId: categoryExists ? currentCategory : null,
          clearCategory: !categoryExists,
          paymentMode: paymentMode,
          splitCash: paymentMode == PosPaymentMode.split ? state.splitCash : 0,
          cart: cart,
          isRefreshing: false,
          clearFailure: true,
          clearError: true,
          shift: shift,
          clearShift: shift == null,
          shiftKnown: shiftKnown,
          isLoadingShift: false,
          shiftFailure: shiftFailure,
          clearShiftFailure: shiftFailure == null,
        ),
      );
    } on PosCatalogException catch (error) {
      _failFetch(request, error.failure, error.message);
    } catch (error) {
      _failFetch(request, PosCatalogFailure.failed, '$error');
    }
  }

  /// Keeps the cashier's mode when the new menu still supports it, otherwise
  /// falls back to cash and then card.
  PosPaymentMode _resolvePaymentMode(List<PosPaymentMethod> methods) {
    final hasCash = methods.any((method) => method.isCash);
    final hasCard = methods.any((method) => method.isCard);
    return switch (state.paymentMode) {
      PosPaymentMode.split when hasCash && hasCard => PosPaymentMode.split,
      PosPaymentMode.card when hasCard => PosPaymentMode.card,
      _ when hasCash => PosPaymentMode.cash,
      _ when hasCard => PosPaymentMode.card,
      _ => PosPaymentMode.cash,
    };
  }

  void _failFetch(int request, PosCatalogFailure failure, String? message) {
    if (isClosed || request != _requestId) return;
    emit(
      state.copyWith(
        status: state.hasData ? PosStatus.ready : PosStatus.failure,
        isRefreshing: false,
        isLoadingTables: false,
        isLoadingShift: false,
        failure: failure,
        errorMessage: message,
      ),
    );
  }

  List<PosCartLine> _reconcileCart(
    PosCatalog catalog,
    List<PosCartLine> lines,
  ) {
    if (lines.isEmpty) return lines;
    final result = <PosCartLine>[];
    final taken = <String, int>{};

    for (final line in lines) {
      final product = catalog.productById(line.product.id);
      if (product == null || !product.isSellable) continue;

      final allowed = <String, PosOptionValue>{};
      var valid = true;
      for (final selected in line.options) {
        PosOptionValue? match;
        for (final group in product.optionGroups) {
          for (final value in group.values) {
            if (value.id == selected.id) {
              match = value;
              break;
            }
          }
          if (match != null) break;
        }
        if (match == null) {
          valid = false;
          break;
        }
        allowed[match.id] = match;
      }
      if (!valid) continue;

      for (final group in product.optionGroups) {
        final ids = {for (final value in group.values) value.id};
        final count = allowed.keys.where(ids.contains).length;
        if (!group.accepts(count)) {
          valid = false;
          break;
        }
      }
      if (!valid) continue;

      var quantity = min(line.quantity, 99);
      final limit = product.stockLimit;
      if (limit != null) {
        final available = limit - (taken[product.id] ?? 0);
        if (available <= 0) continue;
        quantity = min(quantity, available);
      }
      if (quantity <= 0) continue;

      taken[product.id] = (taken[product.id] ?? 0) + quantity;
      result.add(
        PosCartLine(
          product: product,
          options: allowed.values.toList(growable: false),
          quantity: quantity,
          note: line.note,
        ),
      );
    }

    return List<PosCartLine>.unmodifiable(result);
  }

  List<PosOptionValue>? _validatedOptions(
    PosProduct product,
    List<PosOptionValue> options,
  ) {
    final allowed = <String, PosOptionValue>{};
    for (final group in product.optionGroups) {
      for (final value in group.values) {
        allowed[value.id] = value;
      }
    }

    final selected = <String, PosOptionValue>{};
    for (final option in options) {
      final match = allowed[option.id];
      if (match == null) return null;
      selected[match.id] = match;
    }

    for (final group in product.optionGroups) {
      final ids = {for (final value in group.values) value.id};
      final count = selected.keys.where(ids.contains).length;
      if (!group.accepts(count)) return null;
    }

    return selected.values.toList(growable: false);
  }

  static String _defaultCheckoutKey() {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final random = Random.secure()
        .nextInt(0xFFFFFFFF)
        .toRadixString(16)
        .padLeft(8, '0');
    return 'pos-$stamp-$random';
  }
}
