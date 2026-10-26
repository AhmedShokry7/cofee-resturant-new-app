import 'package:admin_app/features/pos/data/models/pos_json.dart';

enum PosShiftStatus {
  open,
  closed;

  static PosShiftStatus fromValue(Object? value) =>
      '$value'.trim().toLowerCase() == 'closed'
      ? PosShiftStatus.closed
      : PosShiftStatus.open;
}

enum PosCashMovementKind {
  cashIn('cash_in'),
  cashOut('cash_out');

  const PosCashMovementKind(this.value);

  final String value;

  static PosCashMovementKind fromValue(Object? value) =>
      '$value'.trim().toLowerCase() == 'cash_out'
      ? PosCashMovementKind.cashOut
      : PosCashMovementKind.cashIn;
}

class PosCashMovement {
  const PosCashMovement({
    required this.id,
    required this.kind,
    this.amount = 0,
    this.reason = '',
    this.createdByName = '',
    this.createdAt,
  });

  final String id;
  final PosCashMovementKind kind;
  final double amount;
  final String reason;
  final String createdByName;
  final DateTime? createdAt;

  bool get isCashIn => kind == PosCashMovementKind.cashIn;

  factory PosCashMovement.fromJson(Map<String, dynamic> json) {
    return PosCashMovement(
      id: posText(json['id']),
      kind: PosCashMovementKind.fromValue(json['kind']),
      amount: posNumber(json['amount']),
      reason: posText(json['reason']),
      createdByName: posText(json['created_by_name']),
      createdAt: posDate(json['created_at']),
    );
  }
}

/// A cashier shift: the register session that owns the branch drawer.
///
/// While open, the money figures are live totals from the server. Once
/// closed, they are the Z totals snapshotted at the drawer count.
class PosShift {
  const PosShift({
    required this.id,
    required this.branchId,
    this.status = PosShiftStatus.open,
    this.openingFloat = 0,
    this.cashSales = 0,
    this.cardSales = 0,
    this.salesTotal = 0,
    this.orderCount = 0,
    this.cashIn = 0,
    this.cashOut = 0,
    this.expectedCash = 0,
    this.countedCash,
    this.variance,
    this.currencyCode = 'SAR',
    this.openedByName = '',
    this.closedByName = '',
    this.openedAt,
    this.closedAt,
    this.note = '',
    this.closeNote = '',
    this.movements = const <PosCashMovement>[],
    this.alreadyOpen = false,
  });

  final String id;
  final String branchId;
  final PosShiftStatus status;
  final double openingFloat;
  final double cashSales;
  final double cardSales;
  final double salesTotal;
  final int orderCount;
  final double cashIn;
  final double cashOut;
  final double expectedCash;

  /// The counted drawer. Null while the shift is still open.
  final double? countedCash;

  /// Counted cash minus expected cash. Null while the shift is still open.
  final double? variance;

  final String currencyCode;
  final String openedByName;
  final String closedByName;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final String note;
  final String closeNote;
  final List<PosCashMovement> movements;

  /// True when the server found a shift already open instead of creating one.
  final bool alreadyOpen;

  bool get isOpen => status == PosShiftStatus.open;

  bool get isClosed => status == PosShiftStatus.closed;

  double get cashNet => cashIn - cashOut;

  /// The drawer amount the cashier should find: opening float, cash sales and
  /// paid-in cash, minus paid-out cash.
  double get expectedDrawer => cashSales + openingFloat + cashIn - cashOut;

  bool get hasVariance {
    final value = variance;
    return value != null && value.abs() >= 0.01;
  }

  bool get isShort => (variance ?? 0) < -0.005;

  bool get isOver => (variance ?? 0) > 0.005;

  factory PosShift.fromJson(Map<String, dynamic> json) {
    return PosShift(
      id: posText(json['id']),
      branchId: posText(json['branch_id']),
      status: PosShiftStatus.fromValue(json['status']),
      openingFloat: posNumber(json['opening_float']),
      cashSales: posNumber(json['cash_sales']),
      cardSales: posNumber(json['card_sales']),
      salesTotal: posNumber(json['sales_total']),
      orderCount: posInteger(json['order_count']),
      cashIn: posNumber(json['cash_in']),
      cashOut: posNumber(json['cash_out']),
      expectedCash: posNumber(json['expected_cash']),
      countedCash: posNumberOrNull(json['counted_cash']),
      variance: posNumberOrNull(json['variance']),
      currencyCode: posText(json['currency_code']).isEmpty
          ? 'SAR'
          : posText(json['currency_code']),
      openedByName: posText(json['opened_by_name']),
      closedByName: posText(json['closed_by_name']),
      openedAt: posDate(json['opened_at']),
      closedAt: posDate(json['closed_at']),
      note: posText(json['note']),
      closeNote: posText(json['close_note']),
      movements: posMaps(json['movements'])
          .map(PosCashMovement.fromJson)
          .toList(growable: false),
      alreadyOpen: posFlag(json['already_open']),
    );
  }
}
