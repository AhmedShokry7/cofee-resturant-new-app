import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/app_dependencies.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/catalog/catalog_data.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/domain/repositories/order_repository.dart';
import 'package:admin_app/features/orders/domain/usecases/add_order_item.dart';
import 'package:admin_app/features/orders/domain/usecases/load_orders.dart';
import 'package:admin_app/features/orders/domain/usecases/remove_order_item.dart';
import 'package:admin_app/features/orders/domain/usecases/update_order_status.dart';
import 'package:admin_app/features/orders/domain/usecases/update_payment_status.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_state.dart';

class AdminOrderCubit extends Cubit<AdminOrderState> {
  AdminOrderCubit({OrderRepository? repository, CatalogData? productRepository})
    : this._withUseCases(
        repository ?? AppDependencies.orders,
        productRepository ?? AppDependencies.catalog,
      );

  AdminOrderCubit._withUseCases(
    OrderRepository repository,
    CatalogData productRepository,
  ) : _loadOrders = LoadOrdersUseCase(repository),
      _updateOrderStatus = UpdateOrderStatusUseCase(repository),
      _updatePaymentStatus = UpdatePaymentStatusUseCase(repository),
      _addOrderItem = AddOrderItemUseCase(repository),
      _removeOrderItem = RemoveOrderItemUseCase(repository),
      _productRepository = productRepository,
      super(const AdminOrderState());

  final LoadOrdersUseCase _loadOrders;
  final UpdateOrderStatusUseCase _updateOrderStatus;
  final UpdatePaymentStatusUseCase _updatePaymentStatus;
  final AddOrderItemUseCase _addOrderItem;
  final RemoveOrderItemUseCase _removeOrderItem;
  final CatalogData _productRepository;
  int _loadRevision = 0;

  CatalogData get productRepository => _productRepository;

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

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _updateOrderStatus(orderId, status);
    await load();
  }

  Future<void> updatePaymentStatus(String orderId, String paymentStatus) async {
    await _updatePaymentStatus(orderId, paymentStatus);
    await load();
  }

  Future<void> addOrderItem(
    String orderId,
    String productId,
    int quantity,
  ) async {
    await _addOrderItem(orderId, productId, quantity);
  }

  Future<void> removeOrderItem(String itemId) async {
    await _removeOrderItem(itemId);
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
}
