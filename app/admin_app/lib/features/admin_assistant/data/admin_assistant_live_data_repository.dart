import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_business_data.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_customer_snapshot.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_offline_responder.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_operational_read_repository.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/loyalty/data/repositories/admin_loyalty_repository.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_member.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_transaction.dart';
import 'package:admin_app/features/dashboard/data/models/admin_dashboard_metrics_model.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_metrics.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_item.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_metrics.dart';
import 'package:admin_app/features/pos/data/repositories/admin_pos_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only adapter over existing dashboard and inventory repositories/RPCs.
/// The database functions enforce staff role, branch scope, and each read
/// permission. This class never issues table SQL or any write operation.
class AdminAssistantLiveDataRepository {
  AdminAssistantLiveDataRepository({this.client, this.session});

  final SupabaseClient? client;
  final AdminSession? session;
  SupabaseClient get _db => client ?? SupabaseService.client;

  Future<AdminAssistantBusinessData?> loadFor(String query) async {
    final analysis = AdminAssistantOfflineResponder.understand(query);
    if (analysis.intent != AdminAssistantOfflineIntent.liveBusinessData) {
      return null;
    }

    switch (analysis.liveDataKind) {
      case 'inventory':
        return _loadInventory(analysis.normalizedText);
      case 'sales':
      case 'orders':
      case 'top_products':
      case 'customer_metrics':
        return _loadDashboard(analysis.liveDataKind);
      case 'discounts':
        return _loadDiscounts(analysis.normalizedText);
      case 'customer_loyalty':
      case 'customer_history':
      case 'customer_history_and_loyalty':
      case 'customer_loyalty_activity':
      case 'customer_history_and_loyalty_activity':
        return _loadCustomer(analysis.normalizedText, analysis.liveDataKind);
      case 'product_catalog':
      case 'product_details':
        return _loadProductCatalog(
          analysis.normalizedText,
          analysis.liveDataKind,
        );
      case 'order_lookup':
        return _loadOrder(query);
      case 'order_metrics':
        final window = _requestedWindow(analysis.normalizedText);
        return _loadOperational(
          AdminAssistantOperationalReadRepository(
            client: _db,
            session: session,
          ).loadOrders(from: window.$1, until: window.$2),
        );
      case 'payment_metrics':
        final window = _requestedWindow(analysis.normalizedText);
        return _loadOperational(
          AdminAssistantOperationalReadRepository(
            client: _db,
            session: session,
          ).loadPayments(from: window.$1, until: window.$2),
        );
      case 'dining_summary':
        return _loadOperational(
          AdminAssistantOperationalReadRepository(
            client: _db,
            session: session,
          ).loadDining(),
        );
      case 'inventory_movements':
        return _loadOperational(
          AdminAssistantOperationalReadRepository(
            client: _db,
            session: session,
          ).loadInventoryMovements(),
        );
      default:
        return AdminAssistantBusinessData(
          kind: analysis.liveDataKind,
          status: AdminAssistantDataStatus.unsupported,
        );
    }
  }

  Future<AdminAssistantBusinessData> _loadOperational(
    Future<AdminAssistantOperationalRead> pending,
  ) async {
    final result = await pending;
    return AdminAssistantBusinessData(
      kind: result.kind,
      status: switch (result.status) {
        AdminAssistantOperationalReadStatus.ready =>
          AdminAssistantDataStatus.ready,
        AdminAssistantOperationalReadStatus.permissionDenied =>
          AdminAssistantDataStatus.permissionDenied,
        AdminAssistantOperationalReadStatus.unavailable =>
          AdminAssistantDataStatus.unavailable,
      },
      operationalRead: result,
    );
  }

  (DateTime?, DateTime?) _requestedWindow(String normalizedQuery) {
    final now = DateTime.now();
    if (normalizedQuery.contains('امبارح') ||
        normalizedQuery.contains('امس') ||
        normalizedQuery.contains('yesterday')) {
      final end = DateTime(now.year, now.month, now.day);
      return (end.subtract(const Duration(days: 1)), end);
    }
    if (normalizedQuery.contains('النهارده') ||
        normalizedQuery.contains('النهاردة') ||
        normalizedQuery.contains('اليوم') ||
        normalizedQuery.contains('today')) {
      final start = DateTime(now.year, now.month, now.day);
      return (start, start.add(const Duration(days: 1)));
    }
    if (normalizedQuery.contains('من اول الشهر') ||
        normalizedQuery.contains('بداية الشهر') ||
        normalizedQuery.contains('this month') ||
        normalizedQuery.contains('month to date')) {
      return (DateTime(now.year, now.month), now);
    }
    return (null, null); // The server reports its bounded 30-day default.
  }

  Future<AdminAssistantBusinessData> _loadOrder(String query) async {
    if (!(session?.hasPermission('orders.read') ?? false)) {
      return const AdminAssistantBusinessData(
        kind: 'order_lookup',
        status: AdminAssistantDataStatus.permissionDenied,
      );
    }
    try {
      final search = _orderSearchTerm(query);
      if (search.length < 2) {
        return const AdminAssistantBusinessData(
          kind: 'order_lookup',
          status: AdminAssistantDataStatus.ready,
          orderLookupRequested: true,
        );
      }
      final raw = await _db
          .rpc(
            'admin_assistant_order_search',
            params: {'p_search': search, 'p_limit': 10},
          )
          .timeout(const Duration(seconds: 8));
      final rows = raw is Map ? raw['rows'] : null;
      return AdminAssistantBusinessData(
        kind: 'order_lookup',
        status: AdminAssistantDataStatus.ready,
        orderLookupRequested: true,
        orders: rows is List
            ? rows
                  .whereType<Map>()
                  .map(Map<String, dynamic>.from)
                  .toList(growable: false)
            : const [],
      );
    } on PostgrestException catch (error) {
      return AdminAssistantBusinessData(
        kind: 'order_lookup',
        status: error.code == '42501'
            ? AdminAssistantDataStatus.permissionDenied
            : AdminAssistantDataStatus.unavailable,
      );
    } catch (_) {
      return const AdminAssistantBusinessData(
        kind: 'order_lookup',
        status: AdminAssistantDataStatus.unavailable,
      );
    }
  }

  String _orderSearchTerm(String query) {
    final reference = RegExp(r'\b[A-Za-z]{2,}[-/]\d{2,}(?:[-/]\d+)?\b')
        .firstMatch(query)
        ?.group(0);
    if (reference != null) return reference;
    final tokens = _normalize(query)
        .split(' ')
        .where((word) => word.length >= 2 && !_orderStopWords.contains(word))
        .toList(growable: false);
    return tokens.take(4).join(' ');
  }

  Future<AdminAssistantBusinessData> _loadProductCatalog(
    String query,
    String kind,
  ) async {
    if (!(session?.hasPermission('pos.manage') ?? false)) {
      return AdminAssistantBusinessData(
        kind: kind,
        status: AdminAssistantDataStatus.permissionDenied,
      );
    }
    try {
      final catalog = await AdminPosRepository(_db)
          .loadCatalog()
          .timeout(const Duration(seconds: 8));
      return AdminAssistantBusinessData(
        kind: kind,
        status: AdminAssistantDataStatus.ready,
        productCatalog: catalog,
      );
    } on PostgrestException catch (error) {
      return AdminAssistantBusinessData(
        kind: kind,
        status: error.code == '42501'
            ? AdminAssistantDataStatus.permissionDenied
            : AdminAssistantDataStatus.unavailable,
      );
    } catch (_) {
      return AdminAssistantBusinessData(
        kind: kind,
        status: AdminAssistantDataStatus.unavailable,
      );
    }
  }

  Future<AdminAssistantBusinessData> _loadCustomer(
    String query,
    String kind,
  ) async {
    final wantsHistory = kind.startsWith('customer_history');
    final wantsPoints = kind.contains('loyalty');
    final wantsLoyaltyActivity = kind.contains('activity');
    // Customer history now uses assistant-only server RPCs that scope every
    // order through the caller's staff branch assignments. Loyalty balances
    // and ledger rows have no branch attribution, so keep them all-branch only.
    final canReadAcrossAllBranches = session?.canManageAllBranches ?? false;
    var canReadHistory = session?.hasPermission('customers.read') ?? false;
    var canReadPoints =
        canReadAcrossAllBranches &&
        (session?.hasPermission('loyalty.read') ?? false);
    if ((!wantsHistory || !canReadHistory) &&
        (!wantsPoints || !canReadPoints) &&
        (!canReadHistory && !canReadPoints)) {
      return AdminAssistantBusinessData(
        kind: kind,
        status: AdminAssistantDataStatus.permissionDenied,
      );
    }

    List<AdminCustomer>? customers;
    List<AdminLoyaltyMember>? members;
    var hadReadFailure = false;
    if (wantsHistory && canReadHistory) {
      try {
        final search = _customerSearch(query);
        final raw = await _db
            .rpc(
              'admin_assistant_customer_directory',
              params: {'p_search': search, 'p_limit': 20},
            )
            .timeout(const Duration(seconds: 6));
        final rows = raw is Map ? raw['rows'] : null;
        customers = rows is List
            ? rows
                  .whereType<Map>()
                  .map(
                    (row) =>
                        AdminCustomer.fromJson(Map<String, dynamic>.from(row)),
                  )
                  .toList(growable: false)
            : const <AdminCustomer>[];
      } on PostgrestException catch (error) {
        if (error.code == '42501') {
          canReadHistory = false;
        } else {
          hadReadFailure = true;
        }
      } catch (_) {
        hadReadFailure = true;
      }
    }
    if (wantsPoints && canReadPoints) {
      try {
        members = await AdminLoyaltyRepository(_db)
            .loadMembers()
            .timeout(const Duration(seconds: 6));
      } on PostgrestException catch (error) {
        if (error.code == '42501') {
          canReadPoints = false;
        } else {
          hadReadFailure = true;
        }
      } catch (_) {
        hadReadFailure = true;
      }
    }
    if (hadReadFailure) {
      return AdminAssistantBusinessData(
        kind: kind,
        status: AdminAssistantDataStatus.unavailable,
      );
    }
    if (!canReadHistory && !canReadPoints) {
      return AdminAssistantBusinessData(
        kind: kind,
        status: AdminAssistantDataStatus.permissionDenied,
      );
    }

    final candidates = <String, _CustomerCandidate>{};
    for (final customer in customers ?? const <AdminCustomer>[]) {
      if (customer.fullName?.trim().isNotEmpty != true) continue;
      candidates[customer.id] = _CustomerCandidate(
        id: customer.id,
        name: customer.fullName!.trim(),
        orderCount: customer.ordersCount,
        totalSpent: customer.totalSpent,
        lastOrderAt: customer.lastOrderAt,
      );
    }
    for (final member in members ?? const <AdminLoyaltyMember>[]) {
      if (member.fullName?.trim().isNotEmpty != true) continue;
      final previous = candidates[member.userId];
      candidates[member.userId] = _CustomerCandidate(
        id: member.userId,
        name: member.fullName!.trim(),
        orderCount: previous?.orderCount,
        totalSpent: previous?.totalSpent,
        lastOrderAt: previous?.lastOrderAt,
        pointsBalance: member.pointsBalance,
        lifetimePoints: member.lifetimePoints,
      );
    }

    final matches = _matchCustomers(query, candidates.values.toList());
    if (matches.length > 1) {
      return AdminAssistantBusinessData(
        kind: kind,
        status: AdminAssistantDataStatus.ready,
        customer: AdminAssistantCustomerSnapshot(
          canReadCustomerHistory: canReadHistory,
          canReadLoyalty: canReadPoints,
          ambiguous: true,
        ),
      );
    }
    if (matches.isEmpty) {
      return AdminAssistantBusinessData(
        kind: kind,
        status: hadReadFailure && customers == null && members == null
            ? AdminAssistantDataStatus.unavailable
            : AdminAssistantDataStatus.ready,
        customer: AdminAssistantCustomerSnapshot(
          canReadCustomerHistory: canReadHistory,
          canReadLoyalty: canReadPoints,
          notFound: true,
        ),
      );
    }

    final candidate = matches.single;
    AdminLoyaltyMember? member;
    for (final possibleMember in members ?? const <AdminLoyaltyMember>[]) {
      if (possibleMember.userId == candidate.id) {
        member = possibleMember;
        break;
      }
    }
    List<AdminAssistantCustomerOrder> orderDetails = const [];
    if (wantsHistory && canReadHistory) {
      try {
        final rawOrders = await _db
            .rpc(
              'admin_assistant_customer_orders',
              params: {'p_customer_id': candidate.id, 'p_limit': 5},
            )
            .timeout(const Duration(seconds: 8));
        if (rawOrders is List) {
          orderDetails = rawOrders
              .whereType<Map>()
              .take(5)
              .map((row) => _orderFromJson(Map<String, dynamic>.from(row)))
              .toList(growable: false);
        }
      } on PostgrestException catch (error) {
        if (error.code == '42501') {
          canReadHistory = false;
        } else {
          return AdminAssistantBusinessData(
            kind: kind,
            status: AdminAssistantDataStatus.unavailable,
          );
        }
      } catch (_) {
        return AdminAssistantBusinessData(
          kind: kind,
          status: AdminAssistantDataStatus.unavailable,
        );
      }
    }
    List<AdminAssistantLoyaltyActivity> loyaltyActivity = const [];
    if (wantsLoyaltyActivity && canReadPoints) {
      try {
        final feed = await AdminLoyaltyRepository(_db)
            .loadTransactions(limit: 300)
            .timeout(const Duration(seconds: 8));
        loyaltyActivity = feed.rows
            .where((transaction) => transaction.userId == candidate.id)
            .take(5)
            .map(_loyaltyActivityFromEntity)
            .toList(growable: false);
      } on PostgrestException catch (error) {
        if (error.code == '42501') {
          canReadPoints = false;
        } else {
          return AdminAssistantBusinessData(
            kind: kind,
            status: AdminAssistantDataStatus.unavailable,
          );
        }
      } catch (_) {
        return AdminAssistantBusinessData(
          kind: kind,
          status: AdminAssistantDataStatus.unavailable,
        );
      }
    }
    return AdminAssistantBusinessData(
      kind: kind,
      status: AdminAssistantDataStatus.ready,
      customer: AdminAssistantCustomerSnapshot(
        canReadCustomerHistory: canReadHistory,
        canReadLoyalty: canReadPoints,
        customerName: candidate.name,
        orderCount: candidate.orderCount,
        totalSpent: candidate.totalSpent,
        lastOrderAt: candidate.lastOrderAt,
        pointsBalance: member?.pointsBalance ?? candidate.pointsBalance,
        lifetimePoints: member?.lifetimePoints ?? candidate.lifetimePoints,
        orders: orderDetails,
        loyaltyActivity: loyaltyActivity,
      ),
    );
  }

  String _customerSearch(String query) {
    final tokens = _normalize(query)
        .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), ' ')
        .split(' ')
        .where((word) => word.length >= 2 && !_customerStopWords.contains(word))
        .toList(growable: false);
    // A bounded name substring search is safer than loading the whole
    // customer directory into the admin client.
    return tokens.take(4).join(' ');
  }

  AdminAssistantLoyaltyActivity _loyaltyActivityFromEntity(
    AdminLoyaltyTransaction transaction,
  ) {
    final rewardName = AppLocale.instance.isArabic
        ? transaction.rewardProductNameAr ?? transaction.rewardProductNameEn
        : transaction.rewardProductNameEn ?? transaction.rewardProductNameAr;
    return AdminAssistantLoyaltyActivity(
      points: transaction.points,
      balanceAfter: transaction.balanceAfter,
      date: transaction.createdAt,
      rewardName: rewardName,
    );
  }

  List<_CustomerCandidate> _matchCustomers(
    String query,
    List<_CustomerCandidate> candidates,
  ) {
    final tokens = _normalize(query)
        .split(' ')
        .where((word) => word.length >= 3 && !_customerStopWords.contains(word))
        .toSet();
    var bestScore = 0;
    final matches = <_CustomerCandidate>[];
    for (final candidate in candidates) {
      final nameTokens = _normalize(candidate.name)
          .split(' ')
          .where((word) => word.length >= 3)
          .toSet();
      final score = nameTokens.intersection(tokens).length;
      if (score == 0) continue;
      if (score > bestScore) {
        bestScore = score;
        matches
          ..clear()
          ..add(candidate);
      } else if (score == bestScore) {
        matches.add(candidate);
      }
    }
    return matches;
  }

  AdminAssistantCustomerOrder _orderFromJson(Map<String, dynamic> row) {
    final isArabic = AppLocale.instance.isArabic;
    final branch = isArabic
        ? row['branch_name_ar']?.toString()
        : row['branch_name_en']?.toString();
    final rawItems = row['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .take(8)
              .map((item) {
                final values = Map<String, dynamic>.from(item);
                final primary = isArabic
                    ? values['product_name_ar']?.toString().trim()
                    : values['product_name_en']?.toString().trim();
                final other = isArabic
                    ? values['product_name_en']?.toString().trim()
                    : values['product_name_ar']?.toString().trim();
                final name = primary;
                final fallback = other;
                final label = name?.isNotEmpty == true
                    ? name!
                    : (fallback ?? '');
                final quantity = values['quantity'] ?? 1;
                return label.isEmpty ? '' : '$label × $quantity';
              })
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    return AdminAssistantCustomerOrder(
      date: DateTime.tryParse('${row['placed_at'] ?? ''}'),
      status: '${row['status'] ?? ''}',
      total: row['grand_total'] is num
          ? (row['grand_total'] as num).toDouble()
          : double.tryParse('${row['grand_total'] ?? 0}') ?? 0,
      branchName: branch,
      items: items,
    );
  }

  Future<AdminAssistantBusinessData> _loadDashboard(String kind) async {
    try {
      final raw = await _db
          .rpc('admin_dashboard_metrics')
          .timeout(const Duration(seconds: 5));
      if (raw is! Map) {
        return AdminAssistantBusinessData(
          kind: kind,
          status: AdminAssistantDataStatus.unavailable,
        );
      }
      final metrics = AdminDashboardMetricsModel.fromJson(
        Map<String, dynamic>.from(raw),
      );
      return AdminAssistantBusinessData(
        kind: kind,
        status: AdminAssistantDataStatus.ready,
        dashboard: metrics,
      );
    } on PostgrestException catch (error) {
      return AdminAssistantBusinessData(
        kind: kind,
        status: error.code == '42501'
            ? AdminAssistantDataStatus.permissionDenied
            : AdminAssistantDataStatus.unavailable,
      );
    } catch (_) {
      return AdminAssistantBusinessData(
        kind: kind,
        status: AdminAssistantDataStatus.unavailable,
      );
    }
  }

  Future<AdminAssistantBusinessData> _loadDiscounts(String query) async {
    if (!(session?.hasPermission('coupons.read') ?? false)) {
      return const AdminAssistantBusinessData(
        kind: 'discounts',
        status: AdminAssistantDataStatus.permissionDenied,
      );
    }
    try {
      final asksPerCoupon =
          AdminAssistantOfflineResponder.asksForPerCouponPerformance(query);
      final raw = await _db
          .rpc('admin_assistant_coupon_report', params: {'p_limit': 100})
          .timeout(const Duration(seconds: 8));
      if (raw is! Map) throw const FormatException('Invalid coupon report');
      final rows = raw['rows'] is List ? raw['rows'] as List : const [];
      final coupons = rows
          .whereType<Map>()
          .map((row) {
            final values = Map<String, dynamic>.from(row);
            return AdminCoupon(
              id: '${values['id'] ?? ''}',
              code: '${values['code'] ?? ''}',
              titleAr: '${values['title_ar'] ?? ''}',
              titleEn: '${values['title_en'] ?? ''}',
              discountType: AdminCouponDiscountType.fromWire(
                values['discount_type'],
              ),
              discountValue: _number(values['discount_value']),
              redemptionsCount: _int(values['redemptions_count']),
              uniqueCustomers: _int(values['unique_customers']),
              discountGiven: _number(values['discount_given']),
              lastRedeemedAt: DateTime.tryParse(
                '${values['last_redeemed_at'] ?? ''}',
              ),
            );
          })
          .toList(growable: false);
      if (asksPerCoupon) {
        return AdminAssistantBusinessData(
          kind: 'discounts',
          status: AdminAssistantDataStatus.ready,
          coupons: coupons,
          couponDirectoryRequested: true,
        );
      }
      final metrics = AdminCouponMetrics(
        total: _int(raw['coupon_count']),
        redemptions: _int(raw['redemptions']),
        uniqueCustomers: _int(raw['unique_customers']),
        discountGiven: _number(raw['discount_given']),
      );
      return AdminAssistantBusinessData(
        kind: 'discounts',
        status: AdminAssistantDataStatus.ready,
        couponMetrics: metrics,
      );
    } on PostgrestException catch (error) {
      return AdminAssistantBusinessData(
        kind: 'discounts',
        status: error.code == '42501'
            ? AdminAssistantDataStatus.permissionDenied
            : AdminAssistantDataStatus.unavailable,
      );
    } catch (_) {
      return const AdminAssistantBusinessData(
        kind: 'discounts',
        status: AdminAssistantDataStatus.unavailable,
      );
    }
  }

  int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  double _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  Future<AdminAssistantBusinessData> _loadInventory(String normalized) async {
    final asksForList = _contains(normalized, const [
      'اي مواد',
      'اي المواد',
      'ما المواد',
      'مواد منخفضة المخزون',
      'المواد منخفضة المخزون',
      'المواد القليلة',
      'المواد النافدة',
      'مواد نافدة',
      'اسماء المواد',
      'اسم المواد',
      'which materials',
      'which raw materials',
      'which items',
      'which materials are low',
      'list materials',
      'show me materials',
      'what items',
      'low stock materials',
    ]);
    final asksLow = _contains(normalized, const [
      'منخفض',
      'low',
      'قليلة المخزون',
      'قربت تخلص',
      'low stock',
    ]);
    final askOut = _contains(normalized, const [
      'نافد',
      'نفد',
      'خلص',
      'out of stock',
      'out of',
    ]);

    try {
      final rawMetrics = await _db
          .rpc('admin_inventory_metrics')
          .timeout(const Duration(seconds: 5));
      if (rawMetrics is! Map) {
        return const AdminAssistantBusinessData(
          kind: 'inventory',
          status: AdminAssistantDataStatus.unavailable,
        );
      }
      final metrics = AdminInventoryMetrics.fromJson(
        Map<String, dynamic>.from(rawMetrics),
      );
      final rows = <AdminInventoryItem>[];
      var truncated = false;
      if (asksForList && (asksLow || askOut)) {
        if (askOut) {
          final page = await _loadMaterials(status: 'out');
          rows.addAll(page.rows);
          truncated = truncated || page.total > page.rows.length;
        }
        if (asksLow) {
          final page = await _loadMaterials(status: 'low');
          rows.addAll(page.rows);
          truncated = truncated || page.total > page.rows.length;
        }
      }
      return AdminAssistantBusinessData(
        kind: 'inventory',
        status: AdminAssistantDataStatus.ready,
        inventory: metrics,
        materials: rows,
        materialListRequested: asksForList && (asksLow || askOut),
        materialListTruncated: truncated,
      );
    } on PostgrestException catch (error) {
      return AdminAssistantBusinessData(
        kind: 'inventory',
        status: error.code == '42501'
            ? AdminAssistantDataStatus.permissionDenied
            : AdminAssistantDataStatus.unavailable,
      );
    } catch (_) {
      return const AdminAssistantBusinessData(
        kind: 'inventory',
        status: AdminAssistantDataStatus.unavailable,
      );
    }
  }

  Future<AdminInventoryPage> _loadMaterials({required String status}) async {
    final raw = await _db
        .rpc(
          'admin_inventory_directory',
          params: <String, dynamic>{
            'p_search': null,
            'p_category': null,
            'p_status': status,
            'p_branch_id': null,
            'p_limit': 12,
            'p_offset': 0,
          },
        )
        .timeout(const Duration(seconds: 5));
    if (raw is! Map) throw const FormatException('Invalid inventory response');
    return AdminInventoryPage.fromJson(Map<String, dynamic>.from(raw));
  }

  static bool _contains(String text, List<String> terms) =>
      terms.any((term) => text.contains(_normalize(term)));

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const _customerStopWords = <String>{
  'انا',
  'العميل',
  'عميل',
  'العملاء',
  'عملاء',
  'رصيد',
  'نقاط',
  'النقاط',
  'ولاء',
  'اشترى',
  'اشترت',
  'اشتر',
  'متى',
  'امتى',
  'ماذا',
  'ايه',
  'ما',
  'من',
  'عمل',
  'له',
  'لها',
  'عنده',
  'عندها',
  'اخر',
  'آخر',
  'طلب',
  'طلباته',
  'طلباتها',
  'تفاصيل',
  'سجل',
  'مشتريات',
  'نقاطه',
  'كم',
  'مجموع',
  'how',
  'many',
  'what',
  'when',
  'did',
  'the',
  'customer',
  'customers',
  'points',
  'point',
  'loyalty',
  'balance',
  'bought',
  'buy',
  'purchase',
  'purchases',
  'last',
  'order',
  'orders',
  'history',
  'details',
  'his',
  'her',
  'for',
  'of',
};

const _orderStopWords = <String>{
  'حاله',
  'حالة',
  'الطلب',
  'طلب',
  'طلبات',
  'تفاصيل',
  'رقم',
  'فين',
  'اين',
  'تابع',
  'اعرف',
  'عايز',
  'اريد',
  'لو',
  'سمحت',
  'العميل',
  'عميل',
  'للعميل',
  'لعميل',
  'order',
  'orders',
  'status',
  'details',
  'number',
  'track',
  'where',
  'is',
  'the',
  'for',
  'customer',
  'please',
  'find',
};

class _CustomerCandidate {
  const _CustomerCandidate({
    required this.id,
    required this.name,
    this.orderCount,
    this.totalSpent,
    this.lastOrderAt,
    this.pointsBalance,
    this.lifetimePoints,
  });

  final String id;
  final String name;
  final int? orderCount;
  final double? totalSpent;
  final DateTime? lastOrderAt;
  final int? pointsBalance;
  final int? lifetimePoints;
}
