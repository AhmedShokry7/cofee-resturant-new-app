import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/payments/di/payments_dependencies.dart';
import 'package:admin_app/features/payments/domain/repositories/payment_repository.dart';
import 'package:admin_app/features/payments/domain/usecases/load_payments.dart';
import 'package:admin_app/features/payments/presentation/manager/admin_payment_state.dart';

class AdminPaymentCubit extends Cubit<AdminPaymentState> {
  AdminPaymentCubit({PaymentRepository? repository})
    : this._withUseCases(repository ?? PaymentsDependencies.repository);

  AdminPaymentCubit._withUseCases(PaymentRepository repository)
    : _loadPayments = LoadPaymentsUseCase(repository),
      super(const AdminPaymentState());

  final LoadPaymentsUseCase _loadPayments;

  Future<void> load() async {
    emit(state.copyWith(status: AdminPaymentStatus.loading, clearError: true));
    try {
      final payments = await _loadPayments();
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
