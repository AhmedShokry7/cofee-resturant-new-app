import 'package:admin_app/features/bundles/data/models/admin_bundle.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';

enum AdminBundleStatus { initial, loading, ready, failure }

class AdminBundleState {
  const AdminBundleState({
    this.status = AdminBundleStatus.initial,
    this.bundles = const <AdminBundle>[],
    this.products = const <AdminProduct>[],
    this.errorMessage,
    this.selectedIds = const <String>{},
    this.isDeletingSelected = false,
  });

  final AdminBundleStatus status;
  final List<AdminBundle> bundles;
  final List<AdminProduct> products;
  final String? errorMessage;

  /// The bundles that are picked for a bulk action.
  final Set<String> selectedIds;

  final bool isDeletingSelected;

  bool get isLoading => status == AdminBundleStatus.loading;
  bool get hasBundles => bundles.isNotEmpty;

  int get selectedCount => selectedIds.length;

  AdminBundleState copyWith({
    AdminBundleStatus? status,
    List<AdminBundle>? bundles,
    List<AdminProduct>? products,
    String? errorMessage,
    bool clearError = false,
    Set<String>? selectedIds,
    bool? isDeletingSelected,
  }) {
    return AdminBundleState(
      status: status ?? this.status,
      bundles: bundles ?? this.bundles,
      products: products ?? this.products,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedIds: selectedIds ?? this.selectedIds,
      isDeletingSelected: isDeletingSelected ?? this.isDeletingSelected,
    );
  }
}
