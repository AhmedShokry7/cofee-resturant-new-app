import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/payments/data/repositories/admin_payment_repository.dart';
import 'package:admin_app/features/payments/presentation/manager/admin_payment_state.dart';

class AdminPaymentCubit extends Cubit<AdminPaymentState> {
  AdminPaymentCubit({AdminPaymentRepository? repository})
    : _repository = repository ?? AdminPaymentRepository(),
      super(const AdminPaymentState());

  final AdminPaymentRepository _repository;

  AdminPaymentRepository get repository => _repository;

  Future<void> load() async {
    emit(state.copyWith(status: AdminPaymentStatus.loading, clearError: true));
    try {
      final payments = await _repository.loadPayments();
      emit(
        state.copyWith(
          status: AdminPaymentStatus.ready,
          payments: payments,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminPaymentStatus.failure,
          errorMessage: '$error',
        ),
      );
    }
  }
}
