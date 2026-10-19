import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/auth/data/models/admin_session.dart';
import 'package:admin_app/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:admin_app/features/dashboard/presentation/manager/dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({
    required AdminSession session,
    DashboardRepository? repository,
  })  : _repository = repository ?? DashboardRepository(),
        _includeOrders = session.hasPermission('orders.read'),
        _includeProducts =
            session.hasPermission('catalog.product.write'),
        _includeCustomers = session.hasPermission('customers.read'),
        super(const DashboardState(status: DashboardStatus.loading));

  final DashboardRepository _repository;
  final bool _includeOrders;
  final bool _includeProducts;
  final bool _includeCustomers;

  Future<void> load() async {
    emit(const DashboardState(status: DashboardStatus.loading));
    try {
      final stats = await _repository.load(
        includeOrders: _includeOrders,
        includeProducts: _includeProducts,
        includeCustomers: _includeCustomers,
        includeBranches: true,
      );
      emit(DashboardState(status: DashboardStatus.ready, stats: stats));
    } catch (error) {
      emit(DashboardState(
        status: DashboardStatus.error,
        errorMessage: '$error',
      ));
    }
  }
}
