import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/subscriptions_admin/data/repositories/admin_subscription_repository.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/manager/admin_subscription_state.dart';

class AdminSubscriptionCubit extends Cubit<AdminSubscriptionState> {
  AdminSubscriptionCubit({AdminSubscriptionRepository? repository})
    : _repository = repository ?? AdminSubscriptionRepository(),
      super(const AdminSubscriptionState());

  final AdminSubscriptionRepository _repository;

  AdminSubscriptionRepository get repository => _repository;

  Future<void> load() async {
    emit(
      state.copyWith(status: AdminSubscriptionStatus.loading, clearError: true),
    );
    try {
      final subs = await _repository.loadSubscriptions();
      emit(
        state.copyWith(
          status: AdminSubscriptionStatus.ready,
          subscriptions: subs,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminSubscriptionStatus.failure,
          errorMessage: '$error',
        ),
      );
    }
  }
}
