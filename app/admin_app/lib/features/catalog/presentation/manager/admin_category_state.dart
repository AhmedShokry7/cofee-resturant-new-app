import 'package:admin_app/core/models/admin_category.dart';

enum AdminCategoryStatus { initial, loading, ready, failure }

class AdminCategoryState {
  const AdminCategoryState({
    this.status = AdminCategoryStatus.initial,
    this.categories = const <AdminCategory>[],
    this.errorMessage,
    this.selectedIds = const <String>{},
    this.isDeletingSelected = false,
  });

  final AdminCategoryStatus status;
  final List<AdminCategory> categories;
  final String? errorMessage;

  /// The categories that are picked for a bulk action.
  final Set<String> selectedIds;

  final bool isDeletingSelected;

  bool get isLoading => status == AdminCategoryStatus.loading;
  bool get hasCategories => categories.isNotEmpty;

  int get selectedCount => selectedIds.length;

  AdminCategoryState copyWith({
    AdminCategoryStatus? status,
    List<AdminCategory>? categories,
    String? errorMessage,
    bool clearError = false,
    Set<String>? selectedIds,
    bool? isDeletingSelected,
  }) {
    return AdminCategoryState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedIds: selectedIds ?? this.selectedIds,
      isDeletingSelected: isDeletingSelected ?? this.isDeletingSelected,
    );
  }
}
