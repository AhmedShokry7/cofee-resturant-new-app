import 'package:admin_app/features/bundles/data/models/admin_bundle.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';

enum AdminBundleStatus { initial, loading, ready, failure }

class AdminBundleState {
  const AdminBundleState({
    this.status = AdminBundleStatus.initial,
    this.bundles = const <AdminBundle>[],
    this.products = const <AdminProduct>[],
    this.errorMessage,
  });

  final AdminBundleStatus status;
  final List<AdminBundle> bundles;
  final List<AdminProduct> products;
  final String? errorMessage;

  bool get isLoading => status == AdminBundleStatus.loading;
  bool get hasBundles => bundles.isNotEmpty;

  AdminBundleState copyWith({
    AdminBundleStatus? status,
    List<AdminBundle>? bundles,
    List<AdminProduct>? products,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminBundleState(
      status: status ?? this.status,
      bundles: bundles ?? this.bundles,
      products: products ?? this.products,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
