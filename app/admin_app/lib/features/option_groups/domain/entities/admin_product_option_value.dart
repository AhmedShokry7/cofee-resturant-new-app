import 'package:admin_app/core/locale/app_locale.dart';

/// خيار واحد كما يسري على مشروب بعينه.
///
/// الرقم الذي يراه العميل ليس `option_values.price_delta` وحده: 229 أضاف جدول
/// `catalog.product_option_value_pricing` يتجاوز الزيادة لـ(مشروب × خيار)،
/// و`catalog.option_value_delta` هي وحدها التي تقرر أي الرقمين يُعمل به. فاللوحة
/// تعرض الرقمين معًا وتبيّن أيهما النافذ، ولا تختار اللوحة بدل القاعدة.
class AdminProductOptionValue {
  const AdminProductOptionValue({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    this.groupDelta = 0,
    this.overrideDelta,
    this.sortOrder = 0,
    this.isDefault = false,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;

  /// الزيادة التي تكتبها المجموعة لكل منتج (`option_values.price_delta`).
  final double groupDelta;

  /// التجاوز الخاص بهذا المشروب، و`null` تعني لا تجاوز: تُعمل زيادة المجموعة.
  final double? overrideDelta;

  final int sortOrder;

  /// الخيار الافتراضي للمجموعة، وهو ما يختاره العميل أول ما يفتح المشروب.
  final bool isDefault;

  /// الزيادة النافذة كما تحلّها `catalog.option_value_delta`.
  double get effectiveDelta => overrideDelta ?? groupDelta;

  /// هل لهذا المشروب سعر خاص به؟ هو ما يُظهر زر «رجوع لسعر المجموعة».
  bool get hasOwnPrice => overrideDelta != null;

  String nameFor(AppLanguage language) => language.isArabic ? nameAr : nameEn;

  factory AdminProductOptionValue.fromJson(
    Map<String, dynamic> json, {
    double? overrideDelta,
  }) {
    return AdminProductOptionValue(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? ''}',
      groupDelta: (json['price_delta'] as num?)?.toDouble() ?? 0,
      overrideDelta: overrideDelta,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isDefault: json['is_default'] == true,
    );
  }
}
