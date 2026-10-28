import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/app_dependencies.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/catalog/catalog_data.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/features/orders/data/services/order_realtime_feed.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/domain/repositories/order_repository.dart';
import 'package:admin_app/features/orders/domain/usecases/add_order_item.dart';
import 'package:admin_app/features/orders/domain/usecases/load_order_status_rules.dart';
import 'package:admin_app/features/orders/domain/usecases/load_orders.dart';
import 'package:admin_app/features/orders/domain/usecases/mark_order_viewed.dart';
import 'package:admin_app/features/orders/domain/usecases/remove_order_item.dart';
import 'package:admin_app/features/orders/domain/usecases/update_order_status.dart';
import 'package:admin_app/features/orders/domain/usecases/update_payment_status.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_state.dart';

class AdminOrderCubit extends Cubit<AdminOrderState> {
  AdminOrderCubit({
    OrderRepository? repository,
    CatalogData? productRepository,
    OrderRealtimeFeed? realtimeFeed,
  }) : this._withUseCases(
         repository ?? AppDependencies.orders,
         productRepository ?? AppDependencies.catalog,
         realtimeFeed,
       );

  AdminOrderCubit._withUseCases(
    OrderRepository repository,
    CatalogData productRepository,
    OrderRealtimeFeed? realtimeFeed,
  ) : _loadOrders = LoadOrdersUseCase(repository),
      _loadStatusRules = LoadOrderStatusRulesUseCase(repository),
      _updateOrderStatus = UpdateOrderStatusUseCase(repository),
      _updatePaymentStatus = UpdatePaymentStatusUseCase(repository),
      _addOrderItem = AddOrderItemUseCase(repository),
      _removeOrderItem = RemoveOrderItemUseCase(repository),
      _markOrderViewed = MarkOrderViewedUseCase(repository),
      _productRepository = productRepository,
      _realtimeFeed = realtimeFeed ?? OrderRealtimeFeed(),
      super(const AdminOrderState());

  final LoadOrdersUseCase _loadOrders;
  final LoadOrderStatusRulesUseCase _loadStatusRules;
  final UpdateOrderStatusUseCase _updateOrderStatus;
  final UpdatePaymentStatusUseCase _updatePaymentStatus;
  final AddOrderItemUseCase _addOrderItem;
  final RemoveOrderItemUseCase _removeOrderItem;
  final MarkOrderViewedUseCase _markOrderViewed;
  final CatalogData _productRepository;
  final OrderRealtimeFeed _realtimeFeed;
  int _loadRevision = 0;
  bool _liveStarted = false;

  CatalogData get productRepository => _productRepository;

  /// يقرأ مرة واحدة الانتقالات التي تسمح بها `orders.status_transitions` لهذا
  /// الموظف، لأن القائمة المبنية على غيرها تعرض أفعالًا سيرفضها الخادم.
  ///
  /// البقاء على `null` عند الفشل يترك القوائم بعهدها السابق — كل الحالات —
  /// فالرفض يبقى مسؤولية الكتابة لا مسؤولية القائمة.
  Future<void> loadStatusRules() async {
    if (isClosed || state.statusRules != null) return;
    try {
      final rules = await _loadStatusRules();
      if (rules == null || isClosed) return;
      emit(state.copyWith(statusRules: rules));
    } catch (_) {
      // تُعرض كل الحالات ولا تُجمَّد الشاشة بسبب قراءة مساعدة.
    }
  }

  /// Listens to the orders table so a ticket fired from the kitchen or an order
  /// placed on a phone reaches the directory without a manual reload.
  void startLiveUpdates() {
    if (_liveStarted) return;
    _liveStarted = true;
    _realtimeFeed.start(_onLiveChange);
  }

  void _onLiveChange() {
    if (isClosed) return;
    refreshLive();
  }

  /// A reload that keeps the rows on screen: the live feed and pull to refresh
  /// use it, so a manager reading a page never watches it flash a spinner. A
  /// failed reload keeps the last orders and reports the error beside them.
  Future<void> refreshLive() async {
    final revision = ++_loadRevision;
    try {
      final orders = await _loadOrders();
      if (isClosed || revision != _loadRevision) return;
      emit(
        state.copyWith(
          status: AdminOrderStatus.ready,
          orders: orders,
          clearError: true,
        ),
      );
    } catch (_) {
      if (isClosed || revision != _loadRevision) return;
      emit(state.copyWith(errorMessage: S.ordersLoadFailed));
    }
  }

  Future<void> load() async {
    final revision = ++_loadRevision;
    emit(state.copyWith(status: AdminOrderStatus.loading, clearError: true));
    try {
      final orders = await _loadOrders();
      if (isClosed || revision != _loadRevision) return;
      final branchRows = await _loadBranches();
      if (isClosed || revision != _loadRevision) return;
      final branches = branchRows
          .map((row) => AdminBranch.fromRow(row))
          .toList(growable: false);
      emit(
        state.copyWith(
          status: AdminOrderStatus.ready,
          orders: orders,
          branches: branches,
          clearError: true,
        ),
      );
    } catch (_) {
      if (isClosed || revision != _loadRevision) return;
      emit(
        state.copyWith(
          status: AdminOrderStatus.failure,
          errorMessage: S.ordersLoadFailed,
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _loadBranches() async {
    try {
      return await _productRepository.loadBranches();
    } catch (_) {
      return const [];
    }
  }

  /// Runs one write with the directory locked, and says whether it ran.
  ///
  /// The order RPCs are not idempotent — a second `admin_add_order_item` adds a
  /// second line, a second status write writes a second history row — so a
  /// write that arrives while another is in flight is dropped rather than
  /// queued. Callers must not apply the change locally unless this returns
  /// true.
  ///
  /// The rows are re-read after every write so the directory shows what the
  /// server kept: an admin who moves an order on the detail screen must not see
  /// the old status or the old total beside it in the list.
  Future<bool> _mutate(Future<void> Function() write) async {
    if (state.saving) return false;
    emit(state.copyWith(saving: true));
    try {
      await write();
      await load();
      return true;
    } finally {
      if (!isClosed) emit(state.copyWith(saving: false));
    }
  }

  Future<bool> updateOrderStatus(String orderId, String status) =>
      _mutate(() => _updateOrderStatus(orderId, status));

  Future<bool> updatePaymentStatus(String orderId, String paymentStatus) =>
      _mutate(() => _updatePaymentStatus(orderId, paymentStatus));

  Future<bool> addOrderItem(String orderId, String productId, int quantity) =>
      _mutate(() => _addOrderItem(orderId, productId, quantity));

  Future<bool> removeOrderItem(String itemId) =>
      _mutate(() => _removeOrderItem(itemId));

  /// يوسم الطلب بأنه فُتح، دون أي تغيير في حالته أو في قائمة الطلبات.
  ///
  /// الوسم يُكتب مرة واحدة في القاعدة، ففتحه مرتين لا ينقص العداد مرتين. فشل
  /// الكتابة يترك الرقم كما هو حتى أول قراءة ناجحة للعدّادات.
  Future<void> markOrderViewed(String orderId) async {
    try {
      await _markOrderViewed(orderId);
    } catch (_) {
      // العداد يُصحَّح عند أول قراءة تالية.
    }
  }

  Future<List<AdminOrder>> loadOrders() async => _loadOrders();

  Future<AdminOrder?> findOrder(String orderId) async {
    final cached = state.orders.where((order) => order.id == orderId);
    if (cached.isNotEmpty) return cached.first;
    final orders = await _loadOrders();
    for (final order in orders) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  Future<dynamic> loadCatalog() => _productRepository.loadCatalog();

  @override
  Future<void> close() async {
    _liveStarted = false;
    await _realtimeFeed.dispose();
    return super.close();
  }
}
