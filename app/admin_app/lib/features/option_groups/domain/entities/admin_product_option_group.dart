import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_default_sizes.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_value.dart';

/// مجموعة أحجام أو إضافات كما تُرى من داخل مشروب واحد.
///
/// `catalog.effective_product_option_groups(product)` في 224 هي التي تجيب «هل
/// ترى هذه المجموعة هذا المشروب»، فاللوحة لا تقرر النطاق بنفسها: `isAttached`
/// نسخةٌ من جواب القاعدة، والزرّ الذي يبدّله يكتب الصفّ الذي يغيّر ذلك الجواب.
class AdminProductOptionGroup {
  const AdminProductOptionGroup({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    this.selectionType = AdminOptionSelectionType.single,
    this.isRequired = false,
    this.sortOrder = 0,
    this.scope = AdminOptionGroupScope.products,
    this.isAttached = false,
    this.values = const <AdminProductOptionValue>[],
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final AdminOptionSelectionType selectionType;

  /// كما تحلّها القاعدة: من كل مستوى (المجموعة أو الفئة أو المنتج) يكفي واحد.
  final bool isRequired;
  final int sortOrder;
  final AdminOptionGroupScope scope;

  /// `true` حين كان المشروب داخل جواب دالة 224 لهذا المشروب.
  final bool isAttached;

  final List<AdminProductOptionValue> values;

  /// نطاق المجموعة هو المنتجات: الصفّ الذي يربطها بهذا المشروب صريح، فيُضاف
  /// ويُحذف. أما `all` و`category` فاشملان، فإلغاء الربط استثناء (`is_excluded`)
  /// لا حذف صفّ.
  bool get bindsProductsDirectly => scope == AdminOptionGroupScope.products;

  /// لا عرض بلا خيارات: مجموعة فارغة لا تعطي المشروب شيئًا.
  bool get hasValues => values.isNotEmpty;

  bool get isSizeGroup =>
      AdminDefaultSizes.isSizeGroup(code: code, nameAr: nameAr, nameEn: nameEn);

  String nameFor(AppLanguage language) => language.isArabic ? nameAr : nameEn;

  factory AdminProductOptionGroup.fromJson(
    Map<String, dynamic> json, {
    bool isAttached = false,
    bool isRequired = false,
    List<AdminProductOptionValue> values = const <AdminProductOptionValue>[],
  }) {
    return AdminProductOptionGroup(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? ''}',
      selectionType: AdminOptionSelectionType.fromKey(
        json['selection_type'] as String?,
      ),
      isRequired: isRequired,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      scope: AdminOptionGroupScope.fromKey(json['applies_to'] as String?),
      isAttached: isAttached,
      values: values,
    );
  }
}
