import 'package:admin_app/features/catalog/data/models/admin_category.dart';

enum AdminCategoryStatus { initial, loading, ready, failure }

class AdminCategoryState {
  const AdminCategoryState({
    this.status = AdminCategoryStatus.initial,
    this.categories = const <AdminCategory>[],
    this.errorMessage,
  });

  final AdminCategoryStatus status;
  final List<AdminCategory> categories;
  final String? errorMessage;

  bool get isLoading => status == AdminCategoryStatus.loading;
  bool get hasCategories => categories.isNotEmpty;

  AdminCategoryState copyWith({
    AdminCategoryStatus? status,
    List<AdminCategory>? categories,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminCategoryState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
