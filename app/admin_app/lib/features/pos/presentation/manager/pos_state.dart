import 'package:admin_app/features/pos/domain/entities/pos_cart.dart';
import 'package:admin_app/features/pos/domain/entities/pos_catalog.dart';
import 'package:admin_app/features/pos/domain/entities/pos_customer.dart';
import 'package:admin_app/features/pos/domain/entities/pos_receipt.dart';
import 'package:admin_app/features/pos/domain/entities/pos_shift.dart';
import 'package:admin_app/features/pos/domain/entities/pos_table.dart';
import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/core/models/dining_table.dart';

enum PosStatus { initial, loading, ready, failure }

/// How the cashier collects the counter sale: cash, card, or both.
enum PosPaymentMode { cash, card, split }

/// The first missing requirement that prevents confirming the order.
enum PosCheckoutBlocker {
  emptyCart,
  branchMissing,
  shiftMissing,
  paymentMissing,
  paymentInvalid,
  tableUnavailable,
}

class PosState {
  const PosState({
    this.status = PosStatus.initial,
    this.branches = const <PosBranch>[],
    this.categories = const <PosCategory>[],
    this.paymentMethods = const <PosPaymentMethod>[],
    this.products = const <PosProduct>[],
    this.branchId,
    this.tables = const <DiningTable>[],
    this.selectedTableId,
    this.tablesFailure,
    this.isLoadingTables = false,
    this.isSeating = false,
    this.currencyCode = 'SAR',
    this.taxRate = 0,
    this.taxIncluded = true,
    this.search = '',
    this.categoryId,
    this.cart = const <PosCartLine>[],
    this.customer,
    this.customerResults = const <PosCustomer>[],
    this.customerQuery = '',
    this.isSearchingCustomers = false,
    this.isCreatingCustomer = false,
    this.customerFailure,
    this.orderNote = '',
    this.paymentMode = PosPaymentMode.cash,
    this.splitCash = 0,
    this.isRefreshing = false,
    this.isPlacingOrder = false,
    this.failure,
    this.errorMessage,
    this.lastReceipt,
    this.shift,
    this.shiftKnown = false,
    this.isLoadingShift = false,
    this.isOpeningShift = false,
    this.isClosingShift = false,
    this.isSavingMovement = false,
    this.shiftFailure,
    this.shiftHistory = const <PosShift>[],
    this.isLoadingShiftHistory = false,
    this.shiftHistoryFailure,
    this.shiftDetail,
    this.isLoadingShiftDetail = false,
  });

  final PosStatus status;
  final List<PosBranch> branches;
  final List<PosCategory> categories;
  final List<PosPaymentMethod> paymentMethods;
  final List<PosProduct> products;
  final String? branchId;
  final List<DiningTable> tables;
  final String? selectedTableId;
  final PosTablesFailure? tablesFailure;
  final bool isLoadingTables;
  final bool isSeating;
  final String currencyCode;
  final double taxRate;
  final bool taxIncluded;
  final String search;
  final String? categoryId;
  final List<PosCartLine> cart;
  final PosCustomer? customer;
  final List<PosCustomer> customerResults;
  final String customerQuery;
  final bool isSearchingCustomers;
  final bool isCreatingCustomer;
  final PosCustomerFailure? customerFailure;
  final String orderNote;
  final PosPaymentMode paymentMode;

  /// The cash portion the cashier typed for a split payment.
  final double splitCash;
  final bool isRefreshing;
  final bool isPlacingOrder;
  final PosCatalogFailure? failure;
  final String? errorMessage;
  final PosReceipt? lastReceipt;

  /// The branch drawer, when one is open.
  final PosShift? shift;

  /// True once the server confirmed whether a shift is open. A failed shift
  /// call leaves this false so a shift-view outage never blocks a sale.
  final bool shiftKnown;
  final bool isLoadingShift;
  final bool isOpeningShift;
  final bool isClosingShift;
  final bool isSavingMovement;
  final PosShiftFailure? shiftFailure;
  final List<PosShift> shiftHistory;
  final bool isLoadingShiftHistory;
  final PosShiftFailure? shiftHistoryFailure;
  final PosShift? shiftDetail;
  final bool isLoadingShiftDetail;

  bool get isLoading => status == PosStatus.loading;
  bool get isFailure => status == PosStatus.failure;
  bool get hasData => products.isNotEmpty || categories.isNotEmpty;
  bool get hasProducts => products.isNotEmpty;

  bool get hasMultipleBranches => branches.length > 1;

  bool get hasActiveFilters => search.trim().isNotEmpty || categoryId != null;

  bool get taxApplies => !taxIncluded && taxRate > 0;

  List<PosProduct> get visibleProducts {
    final category = categoryId;
    final query = search.trim();
    return products
        .where(
          (product) =>
              (category == null || product.categoryId == category) &&
              product.matches(query),
        )
        .toList(growable: false);
  }

  PosBranch? get selectedBranch {
    for (final branch in branches) {
      if (branch.id == branchId) return branch;
    }
    return null;
  }

  PosCategory? get selectedCategory {
    final id = categoryId;
    if (id == null) return null;
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  PosPaymentMethod? get cashMethod => _paymentByCode('cash');

  PosPaymentMethod? get cardMethod => _paymentByCode('card');

  PosPaymentMethod? _paymentByCode(String code) {
    for (final method in paymentMethods) {
      if (method.code == code) return method;
    }
    return null;
  }

  bool get canSplitPayment => cashMethod != null && cardMethod != null;

  /// The primary method sent with the order. A split sale names its larger
  /// portion, with cash winning a tie.
  PosPaymentMethod? get selectedPaymentMethod => switch (paymentMode) {
    PosPaymentMode.cash => cashMethod,
    PosPaymentMode.card => cardMethod,
    PosPaymentMode.split =>
      splitCashAmount >= splitCardAmount ? cashMethod : cardMethod,
  };

  double get cartTotal => cartSummary.total;

  double get splitCashAmount => splitCash <= 0 ? 0 : posRound2(splitCash);

  double get splitCardAmount {
    final rest = posRound2(cartTotal - splitCashAmount);
    return rest > 0 ? rest : 0;
  }

  bool get isSplitAmountValid =>
      canSplitPayment && splitCashAmount > 0 && splitCardAmount > 0;

  /// Both the method and, for a split sale, both portions must be payable.
  bool get paymentReady => switch (paymentMode) {
    PosPaymentMode.cash => cashMethod != null,
    PosPaymentMode.card => cardMethod != null,
    PosPaymentMode.split => isSplitAmountValid,
  };

  bool get hasOpenShift => shift?.isOpen ?? false;

  /// True only when the server said no drawer is open. An unknown state (the
  /// shift call failed) is not treated as missing, so a sale can still be
  /// attempted and the server remains the source of truth.
  bool get shiftMissing => shiftKnown && shift == null;

  static const int shiftHistoryPageSize = 20;

  bool get hasShiftHistory => shiftHistory.isNotEmpty;

  bool get canLoadMoreShiftHistory =>
      shiftHistory.isNotEmpty &&
      shiftHistory.length % shiftHistoryPageSize == 0;

  bool get hasTables => tables.isNotEmpty;

  DiningTable? get selectedTable {
    final id = selectedTableId;
    if (id == null) return null;
    return tableById(id);
  }

  DiningTable? tableById(String id) {
    for (final table in tables) {
      if (table.id == id) return table;
    }
    return null;
  }

  PosProduct? productById(String id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  PosCartSummary get cartSummary => PosCartSummary.fromLines(
    cart,
    taxRate: taxRate,
    taxIncluded: taxIncluded,
  );

  int get cartQuantity => cartSummary.quantity;

  bool get isCartEmpty => cart.isEmpty;

  bool get hasCustomer => customer != null;

  bool get hasCustomerSearch =>
      customerQuery.isNotEmpty ||
      customerResults.isNotEmpty ||
      isSearchingCustomers ||
      customerFailure != null;

  int quantityOf(String productId) {
    var total = 0;
    for (final line in cart) {
      if (line.product.id == productId) total += line.quantity;
    }
    return total;
  }

  /// How many more units of [product] the cart may take. Null is unlimited.
  int? remainingFor(PosProduct product) {
    final limit = product.stockLimit;
    if (limit == null) return null;
    final remaining = limit - quantityOf(product.id);
    return remaining < 0 ? 0 : remaining;
  }

  /// The first requirement the cashier still has to satisfy, mirroring the
  /// checks in `PosCubit.placeOrder`, so the cart can explain a blocked
  /// confirmation instead of silently disabling the button.
  PosCheckoutBlocker? get checkoutBlocker {
    if (cart.isEmpty) return PosCheckoutBlocker.emptyCart;
    final id = branchId;
    if (id == null || id.isEmpty) return PosCheckoutBlocker.branchMissing;
    if (shiftMissing) return PosCheckoutBlocker.shiftMissing;
    if (paymentMethods.isEmpty) return PosCheckoutBlocker.paymentMissing;
    if (!paymentReady) {
      return paymentMode == PosPaymentMode.split
          ? PosCheckoutBlocker.paymentInvalid
          : PosCheckoutBlocker.paymentMissing;
    }
    // A table is optional: only a chosen table that stopped being usable
    // blocks the confirmation.
    final table = selectedTable;
    if (table != null && !table.isPosSelectable) {
      return PosCheckoutBlocker.tableUnavailable;
    }
    return null;
  }

  bool get canCheckout => !isPlacingOrder && checkoutBlocker == null;

  PosState copyWith({
    PosStatus? status,
    List<PosBranch>? branches,
    List<PosCategory>? categories,
    List<PosPaymentMethod>? paymentMethods,
    List<PosProduct>? products,
    String? branchId,
    List<DiningTable>? tables,
    String? selectedTableId,
    bool clearSelectedTable = false,
    PosTablesFailure? tablesFailure,
    bool clearTablesFailure = false,
    bool? isLoadingTables,
    bool? isSeating,
    String? currencyCode,
    double? taxRate,
    bool? taxIncluded,
    String? search,
    String? categoryId,
    bool clearCategory = false,
    List<PosCartLine>? cart,
    PosCustomer? customer,
    bool clearCustomer = false,
    List<PosCustomer>? customerResults,
    String? customerQuery,
    bool? isSearchingCustomers,
    bool? isCreatingCustomer,
    PosCustomerFailure? customerFailure,
    bool clearCustomerFailure = false,
    String? orderNote,
    PosPaymentMode? paymentMode,
    double? splitCash,
    bool? isRefreshing,
    bool? isPlacingOrder,
    PosCatalogFailure? failure,
    bool clearFailure = false,
    String? errorMessage,
    bool clearError = false,
    PosReceipt? lastReceipt,
    bool clearLastReceipt = false,
    PosShift? shift,
    bool clearShift = false,
    bool? shiftKnown,
    bool? isLoadingShift,
    bool? isOpeningShift,
    bool? isClosingShift,
    bool? isSavingMovement,
    PosShiftFailure? shiftFailure,
    bool clearShiftFailure = false,
    List<PosShift>? shiftHistory,
    bool? isLoadingShiftHistory,
    PosShiftFailure? shiftHistoryFailure,
    bool clearShiftHistoryFailure = false,
    PosShift? shiftDetail,
    bool clearShiftDetail = false,
    bool? isLoadingShiftDetail,
  }) {
    return PosState(
      status: status ?? this.status,
      branches: branches ?? this.branches,
      categories: categories ?? this.categories,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      products: products ?? this.products,
      branchId: branchId ?? this.branchId,
      tables: tables ?? this.tables,
      selectedTableId: clearSelectedTable
          ? null
          : (selectedTableId ?? this.selectedTableId),
      tablesFailure: clearTablesFailure
          ? null
          : (tablesFailure ?? this.tablesFailure),
      isLoadingTables: isLoadingTables ?? this.isLoadingTables,
      isSeating: isSeating ?? this.isSeating,
      currencyCode: currencyCode ?? this.currencyCode,
      taxRate: taxRate ?? this.taxRate,
      taxIncluded: taxIncluded ?? this.taxIncluded,
      search: search ?? this.search,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      cart: cart ?? this.cart,
      customer: clearCustomer ? null : (customer ?? this.customer),
      customerResults: customerResults ?? this.customerResults,
      customerQuery: customerQuery ?? this.customerQuery,
      isSearchingCustomers: isSearchingCustomers ?? this.isSearchingCustomers,
      isCreatingCustomer: isCreatingCustomer ?? this.isCreatingCustomer,
      customerFailure: clearCustomerFailure
          ? null
          : (customerFailure ?? this.customerFailure),
      orderNote: orderNote ?? this.orderNote,
      paymentMode: paymentMode ?? this.paymentMode,
      splitCash: splitCash ?? this.splitCash,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isPlacingOrder: isPlacingOrder ?? this.isPlacingOrder,
      failure: clearFailure ? null : (failure ?? this.failure),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastReceipt: clearLastReceipt ? null : (lastReceipt ?? this.lastReceipt),
      shift: clearShift ? null : (shift ?? this.shift),
      shiftKnown: shiftKnown ?? this.shiftKnown,
      isLoadingShift: isLoadingShift ?? this.isLoadingShift,
      isOpeningShift: isOpeningShift ?? this.isOpeningShift,
      isClosingShift: isClosingShift ?? this.isClosingShift,
      isSavingMovement: isSavingMovement ?? this.isSavingMovement,
      shiftFailure: clearShiftFailure
          ? null
          : (shiftFailure ?? this.shiftFailure),
      shiftHistory: shiftHistory ?? this.shiftHistory,
      isLoadingShiftHistory:
          isLoadingShiftHistory ?? this.isLoadingShiftHistory,
      shiftHistoryFailure: clearShiftHistoryFailure
          ? null
          : (shiftHistoryFailure ?? this.shiftHistoryFailure),
      shiftDetail: clearShiftDetail ? null : (shiftDetail ?? this.shiftDetail),
      isLoadingShiftDetail: isLoadingShiftDetail ?? this.isLoadingShiftDetail,
    );
  }
}
