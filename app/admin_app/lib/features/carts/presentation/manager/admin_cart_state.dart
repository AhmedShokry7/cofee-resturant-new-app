import 'package:admin_app/features/carts/data/models/admin_cart.dart';

enum AdminCartStatus { initial, loading, ready, failure }

class AdminCartState {
  const AdminCartState({
    this.status = AdminCartStatus.initial,
    this.carts = const <AdminCart>[],
    this.errorMessage,
  });

  final AdminCartStatus status;
  final List<AdminCart> carts;
  final String? errorMessage;

  bool get isLoading => status == AdminCartStatus.loading;
  bool get hasCarts => carts.isNotEmpty;

  AdminCartState copyWith({
    AdminCartStatus? status,
    List<AdminCart>? carts,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminCartState(
      status: status ?? this.status,
      carts: carts ?? this.carts,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
