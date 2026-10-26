import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/customers/di/customers_dependencies.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer_metrics.dart';
import 'package:admin_app/features/customers/domain/repositories/customer_repository.dart';
import 'package:admin_app/features/customers/domain/usecases/load_customer_details.dart';
import 'package:admin_app/features/customers/domain/usecases/load_customer_metrics.dart';
import 'package:admin_app/features/customers/domain/usecases/load_customers.dart';
import 'package:admin_app/features/customers/domain/usecases/update_customer.dart';
import 'package:admin_app/features/customers/presentation/manager/admin_customer_state.dart';

class AdminCustomerCubit extends Cubit<AdminCustomerState> {
  AdminCustomerCubit({CustomerRepository? repository})
    : this._withUseCases(repository ?? CustomersDependencies.repository);

  AdminCustomerCubit._withUseCases(CustomerRepository repository)
    : _loadCustomers = LoadCustomersUseCase(repository),
      _loadCustomerMetrics = LoadCustomerMetricsUseCase(repository),
      _loadCustomerDetails = LoadCustomerDetailsUseCase(repository),
      _updateCustomer = UpdateCustomerUseCase(repository),
      super(const AdminCustomerState());

  final LoadCustomersUseCase _loadCustomers;
  final LoadCustomerMetricsUseCase _loadCustomerMetrics;
  final LoadCustomerDetailsUseCase _loadCustomerDetails;
  final UpdateCustomerUseCase _updateCustomer;

  Future<void> load() async {
    emit(state.copyWith(status: AdminCustomerStatus.loading, clearError: true));
    try {
      final results = await Future.wait<Object>([
        _loadCustomers(),
        _loadCustomerMetrics(),
      ]);
      emit(
        state.copyWith(
          status: AdminCustomerStatus.ready,
          customers: results[0] as List<AdminCustomer>,
          metrics: results[1] as AdminCustomerMetrics,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminCustomerStatus.failure,
          errorMessage: '$error',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> loadCustomerDetails(String customerId) =>
      _loadCustomerDetails(customerId);

  Future<void> updateCustomer(
    String customerId, {
    bool? isVip,
    bool? isBlacklisted,
    String? adminNotes,
  }) => _updateCustomer(
    customerId,
    isVip: isVip,
    isBlacklisted: isBlacklisted,
    adminNotes: adminNotes,
  );
}
