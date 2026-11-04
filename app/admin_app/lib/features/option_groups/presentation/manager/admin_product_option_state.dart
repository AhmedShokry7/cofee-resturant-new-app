import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_group.dart';

enum AdminProductOptionStatus { initial, loading, ready, failure }

/// حالة حوار «الأحجام والإضافات» لمشروب واحد.
class AdminProductOptionState {
  const AdminProductOptionState({
    this.status = AdminProductOptionStatus.initial,
    this.groups = const <AdminProductOptionGroup>[],
    this.basePrice = 0,
    this.saving = false,
    this.errorMessage,
  });

  final AdminProductOptionStatus status;
  final List<AdminProductOptionGroup> groups;

  /// السعر الأساسي للمنتج، وهو ما تُضاف إليه الزيادة ليُرى السعر النهائي.
  final double basePrice;

  /// الكتابة هنا واحدة في كل مرة: تجاوز سعر أو ربط مجموعة.
  final bool saving;
  final String? errorMessage;

  bool get isLoading => status == AdminProductOptionStatus.loading;
  bool get isReady => status == AdminProductOptionStatus.ready;

  /// المجموعات التي يراها هذا المشروب فعلًا، وهي ما يحلّه جواب 224.
  List<AdminProductOptionGroup> get attachedGroups =>
      groups.where((group) => group.isAttached).toList(growable: false);

  AdminProductOptionState copyWith({
    AdminProductOptionStatus? status,
    List<AdminProductOptionGroup>? groups,
    double? basePrice,
    bool? saving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminProductOptionState(
      status: status ?? this.status,
      groups: groups ?? this.groups,
      basePrice: basePrice ?? this.basePrice,
      saving: saving ?? this.saving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
