import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/data/repositories/admin_order_repository.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_state.dart';

class AdminOrderCubit extends Cubit<AdminOrderState> {
  AdminOrderCubit({
    AdminOrderRepository? repository,
    AdminProductRepository? productRepository,
  }) : _repository = repository ?? AdminOrderRepository(),
       _productRepository = productRepository ?? AdminProductRepository(),
       super(const AdminOrderState());

  final AdminOrderRepository _repository;
  final AdminProductRepository _productRepository;
  int _loadRevision = 0;

  AdminOrderRepository get repository => _repository;
  AdminProductRepository get productRepository => _productRepository;

  Future<void> load() async {
    final revision = ++_loadRevision;
    emit(state.copyWith(status: AdminOrderStatus.loading, clearError: true));
    try {
      final orders = await _repository.loadOrders();
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
    await _repository.updateOrderStatus(orderId, status);
    await load();
  }

  Future<void> updatePaymentStatus(String orderId, String paymentStatus) async {
    await _repository.updatePaymentStatus(orderId, paymentStatus);
    await load();
  }

  Future<void> addOrderItem(
    String orderId,
    String productId,
    int quantity,
  ) async {
    await _repository.addOrderItem(orderId, productId, quantity);
  }

  Future<void> removeOrderItem(String itemId) async {
    await _repository.removeOrderItem(itemId);
  }

  Future<List<AdminOrder>> loadOrders() async => _repository.loadOrders();

  Future<AdminOrder?> findOrder(String orderId) async {
    final cached = state.orders.where((order) => order.id == orderId);
    if (cached.isNotEmpty) return cached.first;
    final orders = await _repository.loadOrders();
    for (final order in orders) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  Future<dynamic> loadCatalog() => _productRepository.loadCatalog();
}
