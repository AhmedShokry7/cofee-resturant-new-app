import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/carts/data/repositories/admin_cart_repository.dart';
import 'package:admin_app/features/carts/presentation/manager/admin_cart_state.dart';

class AdminCartCubit extends Cubit<AdminCartState> {
  AdminCartCubit({AdminCartRepository? repository})
    : _repository = repository ?? AdminCartRepository(),
      super(const AdminCartState());

  final AdminCartRepository _repository;

  AdminCartRepository get repository => _repository;

  Future<void> load() async {
    emit(state.copyWith(status: AdminCartStatus.loading, clearError: true));
    try {
      final carts = await _repository.loadCarts();
      emit(
        state.copyWith(
          status: AdminCartStatus.ready,
          carts: carts,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(status: AdminCartStatus.failure, errorMessage: '$error'),
      );
    }
  }
}
