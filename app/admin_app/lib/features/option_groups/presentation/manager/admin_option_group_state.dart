import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';

enum AdminOptionGroupStatus { initial, loading, ready, failure }

class AdminOptionGroupState {
  const AdminOptionGroupState({
    this.status = AdminOptionGroupStatus.initial,
    this.groups = const <AdminOptionGroup>[],
    this.products = const <AdminProduct>[],
    this.categories = const <AdminCategory>[],
    this.errorMessage,
  });

  final AdminOptionGroupStatus status;
  final List<AdminOptionGroup> groups;

  /// الكتالوج الذي يُنتقى منه النطاق: المنتجات والفئات معًا، وهما اللذان تحلّ
  /// دالة 224 منهما مظهر المجموعة عند العميل.
  final List<AdminProduct> products;
  final List<AdminCategory> categories;
  final String? errorMessage;

  bool get isLoading => status == AdminOptionGroupStatus.loading;
  bool get hasGroups => groups.isNotEmpty;

  AdminOptionGroupState copyWith({
    AdminOptionGroupStatus? status,
    List<AdminOptionGroup>? groups,
    List<AdminProduct>? products,
    List<AdminCategory>? categories,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminOptionGroupState(
      status: status ?? this.status,
      groups: groups ?? this.groups,
      products: products ?? this.products,
      categories: categories ?? this.categories,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
