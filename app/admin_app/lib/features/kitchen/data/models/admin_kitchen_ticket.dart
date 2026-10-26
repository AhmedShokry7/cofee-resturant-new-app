import 'package:admin_app/core/locale/app_locale.dart';

/// The lifecycle of a kitchen ticket.
enum KitchenTicketStatus {
  queued('queued'),
  preparing('preparing'),
  ready('ready'),
  completed('completed'),
  cancelled('cancelled');

  const KitchenTicketStatus(this.value);

  final String value;

  static KitchenTicketStatus fromValue(Object? value) {
    final normalized = '${value ?? ''}'.trim().toLowerCase();
    for (final status in KitchenTicketStatus.values) {
      if (status.value == normalized) return status;
    }
    return KitchenTicketStatus.queued;
  }

  bool get isActive =>
      this == KitchenTicketStatus.queued ||
      this == KitchenTicketStatus.preparing ||
      this == KitchenTicketStatus.ready;
}

/// The per-line state inside a ticket.
enum KitchenItemStatus {
  pending('pending'),
  preparing('preparing'),
  ready('ready');

  const KitchenItemStatus(this.value);

  final String value;

  static KitchenItemStatus fromValue(Object? value) {
    final normalized = '${value ?? ''}'.trim().toLowerCase();
    for (final status in KitchenItemStatus.values) {
      if (status.value == normalized) return status;
    }
    return KitchenItemStatus.pending;
  }
}

class AdminKitchenOption {
  const AdminKitchenOption({required this.nameAr, required this.nameEn});

  final String nameAr;
  final String nameEn;

  String nameFor(AppLanguage language) {
    final primary = language.isArabic ? nameAr : nameEn;
    final fallback = language.isArabic ? nameEn : nameAr;
    final name = primary.trim();
    if (name.isNotEmpty) return name;
    return fallback.trim();
  }

  factory AdminKitchenOption.fromJson(Map<String, dynamic> json) {
    return AdminKitchenOption(
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? ''}',
    );
  }
}

class AdminKitchenTicketItem {
  const AdminKitchenTicketItem({
    required this.id,
    this.status = KitchenItemStatus.pending,
    this.quantity = 1,
    required this.productNameAr,
    required this.productNameEn,
    this.note = '',
    this.optionGroupNameAr = '',
    this.optionGroupNameEn = '',
    this.options = const <AdminKitchenOption>[],
  });

  final String id;
  final KitchenItemStatus status;
  final int quantity;
  final String productNameAr;
  final String productNameEn;
  final String note;
  final String optionGroupNameAr;
  final String optionGroupNameEn;
  final List<AdminKitchenOption> options;

  bool get isReady => status == KitchenItemStatus.ready;

  String nameFor(AppLanguage language) {
    final primary = language.isArabic ? productNameAr : productNameEn;
    final fallback = language.isArabic ? productNameEn : productNameAr;
    final name = primary.trim();
    if (name.isNotEmpty) return name;
    return fallback.trim();
  }

  /// The chosen size/sugar selections, already frozen on the order line.
  String optionsFor(AppLanguage language) {
    final names = <String>[
      for (final option in options)
        if (option.nameFor(language).isNotEmpty) option.nameFor(language),
    ];
    return names.join(' · ');
  }

  factory AdminKitchenTicketItem.fromJson(Map<String, dynamic> json) {
    final options = json['options'];
    return AdminKitchenTicketItem(
      id: '${json['id'] ?? ''}',
      status: KitchenItemStatus.fromValue(json['status']),
      quantity: _toInt(json['quantity'], fallback: 1),
      productNameAr: '${json['product_name_ar'] ?? ''}',
      productNameEn: '${json['product_name_en'] ?? ''}',
      note: '${json['note'] ?? ''}'.trim(),
      optionGroupNameAr: '${json['option_group_name_ar'] ?? ''}',
      optionGroupNameEn: '${json['option_group_name_en'] ?? ''}',
      options: options is List
          ? options
                .whereType<Map>()
                .map(
                  (option) => AdminKitchenOption.fromJson(
                    Map<String, dynamic>.from(option),
                  ),
                )
                .toList(growable: false)
          : const <AdminKitchenOption>[],
    );
  }
}

/// One order as the kitchen board presents it.
class AdminKitchenTicket {
  const AdminKitchenTicket({
    required this.id,
    this.status = KitchenTicketStatus.queued,
    required this.placedAt,
    this.startedAt,
    this.readyAt,
    this.completedAt,
    required this.orderId,
    required this.orderNumber,
    this.orderStatus = '',
    this.fulfillmentType = 'pickup',
    this.orderSource = 'online',
    this.tableNumber,
    this.customerNote = '',
    this.customerName = '',
    required this.branchId,
    this.branchCode = '',
    this.branchNameAr = '',
    this.branchNameEn = '',
    this.itemCount = 0,
    this.readyCount = 0,
    this.items = const <AdminKitchenTicketItem>[],
  });

  final String id;
  final KitchenTicketStatus status;
  final DateTime? placedAt;
  final DateTime? startedAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final String orderId;
  final String orderNumber;
  final String orderStatus;
  final String fulfillmentType;
  final String orderSource;
  final String? tableNumber;
  final String customerNote;
  final String customerName;
  final String branchId;
  final String branchCode;
  final String branchNameAr;
  final String branchNameEn;
  final int itemCount;
  final int readyCount;
  final List<AdminKitchenTicketItem> items;

  bool get isQueued => status == KitchenTicketStatus.queued;
  bool get isPreparing => status == KitchenTicketStatus.preparing;
  bool get isReady => status == KitchenTicketStatus.ready;
  bool get isCompleted => status == KitchenTicketStatus.completed;
  bool get isActive => status.isActive;
  bool get isPos => orderSource == 'pos';
  bool get isDineIn => fulfillmentType == 'dine_in';

  bool get hasCustomerNote => customerNote.trim().isNotEmpty;
  bool get hasCustomerName => customerName.trim().isNotEmpty;

  String branchNameFor(AppLanguage language) {
    final primary = language.isArabic ? branchNameAr : branchNameEn;
    final fallback = language.isArabic ? branchNameEn : branchNameAr;
    final name = primary.trim();
    if (name.isNotEmpty) return name;
    return fallback.trim();
  }

  factory AdminKitchenTicket.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    return AdminKitchenTicket(
      id: '${json['id'] ?? ''}',
      status: KitchenTicketStatus.fromValue(json['status']),
      placedAt: _toDate(json['placed_at']),
      startedAt: _toDate(json['started_at']),
      readyAt: _toDate(json['ready_at']),
      completedAt: _toDate(json['completed_at']),
      orderId: '${json['order_id'] ?? ''}',
      orderNumber: '${json['order_number'] ?? ''}',
      orderStatus: '${json['order_status'] ?? ''}',
      fulfillmentType: '${json['fulfillment_type'] ?? 'pickup'}',
      orderSource: '${json['order_source'] ?? 'online'}',
      tableNumber: _toNullableText(json['table_number']),
      customerNote: '${json['customer_note'] ?? ''}'.trim(),
      customerName: '${json['customer_name'] ?? ''}'.trim(),
      branchId: '${json['branch_id'] ?? ''}',
      branchCode: '${json['branch_code'] ?? ''}',
      branchNameAr: '${json['branch_name_ar'] ?? ''}',
      branchNameEn: '${json['branch_name_en'] ?? ''}',
      itemCount: _toInt(json['item_count']),
      readyCount: _toInt(json['ready_count']),
      items: items is List
          ? items
                .whereType<Map>()
                .map(
                  (item) => AdminKitchenTicketItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <AdminKitchenTicketItem>[],
    );
  }
}

class AdminKitchenBoard {
  const AdminKitchenBoard({
    this.tickets = const <AdminKitchenTicket>[],
    this.total = 0,
  });

  final List<AdminKitchenTicket> tickets;
  final int total;

  factory AdminKitchenBoard.fromJson(Map<String, dynamic> json) {
    final rows = json['rows'];
    return AdminKitchenBoard(
      tickets: rows is List
          ? rows
                .whereType<Map>()
                .map(
                  (row) => AdminKitchenTicket.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList(growable: false)
          : const <AdminKitchenTicket>[],
      total: _toInt(json['total']),
    );
  }
}

int _toInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? fallback;
}

String? _toNullableText(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}

DateTime? _toDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
