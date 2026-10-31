import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/features/carts/di/carts_dependencies.dart';
import 'package:admin_app/features/carts/domain/repositories/cart_repository.dart';
import 'package:admin_app/features/carts/domain/usecases/load_carts.dart';
import 'package:admin_app/features/carts/presentation/manager/admin_cart_state.dart';

class AdminCartCubit extends Cubit<AdminCartState> {
  AdminCartCubit({CartRepository? repository})
    : this._withUseCases(repository ?? CartsDependencies.repository);

  AdminCartCubit._withUseCases(CartRepository repository)
    : _loadCarts = LoadCartsUseCase(repository),
      super(const AdminCartState());

  final LoadCartsUseCase _loadCarts;

  Future<void> load() async {
    emit(state.copyWith(status: AdminCartStatus.loading, clearError: true));
    try {
      final carts = await _loadCarts();
      emit(
        state.copyWith(
          status: AdminCartStatus.ready,
          carts: carts,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminCartStatus.failure,
          errorMessage: adminErrorMessage(error),
        ),
      );
    }
  }
}
