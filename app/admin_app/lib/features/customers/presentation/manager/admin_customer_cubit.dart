import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/customers/data/repositories/admin_customer_repository.dart';
import 'package:admin_app/features/customers/presentation/manager/admin_customer_state.dart';

class AdminCustomerCubit extends Cubit<AdminCustomerState> {
  AdminCustomerCubit({AdminCustomerRepository? repository})
    : _repository = repository ?? AdminCustomerRepository(),
      super(const AdminCustomerState());

  final AdminCustomerRepository _repository;

  AdminCustomerRepository get repository => _repository;

  Future<void> load() async {
    emit(state.copyWith(status: AdminCustomerStatus.loading, clearError: true));
    try {
      final customers = await _repository.loadCustomers();
      emit(
        state.copyWith(
          status: AdminCustomerStatus.ready,
          customers: customers,
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
      _repository.loadCustomerDetails(customerId);

  Future<void> updateCustomer(
    String customerId, {
    bool? isVip,
    bool? isBlacklisted,
    String? adminNotes,
  }) => _repository.updateCustomer(
    customerId,
    isVip: isVip,
    isBlacklisted: isBlacklisted,
    adminNotes: adminNotes,
  );
}
