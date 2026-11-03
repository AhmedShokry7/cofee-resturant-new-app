import 'package:flutter/widgets.dart';

import 'package:admin_app/core/locale/app_locale.dart';

/// منتج كما تصل بطاقته إلى شاشة العميل: اسم وصورة وسعرًا حُسب عند القراءة.
///
/// البطاقة عند الزبون لا تحسب السعر، بل تعرض ما رجع به الصف. من هنا يفصل هذا
/// الكيان عن نموذج اللوحة `AdminProduct` الذي يحمل السعر الأساسي ونافذة الخصم،
/// لأن اللوحة تعدّلهما والعميل يقرأ نتائجهما.
///
/// [price] هو السعر المطبوع، و[oldPrice] المشطوب فوقه حين يوجد. أحدهما إما
/// راجع من القاعدة مباشرة (شريط «الأكثر طلبًا» يرجع بسعره المحسوب)، أو
/// محسوب من نافذة الخصم في `CustomerFeed`.
class PreviewProduct {
  const PreviewProduct({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.price,
    this.categoryId,
    this.categoryAr = '',
    this.categoryEn = '',
    this.categorySlug = '',
    this.descriptionAr,
    this.descriptionEn,
    this.imageUrl,
    this.oldPrice,
    this.imageFit = BoxFit.fill,
  });

  final String id;

  /// التصنيف الذي يجمّع به المحاكي منتجات الشاشة نفسها؛ شريط القاعدة يرجع
  /// أسماء التصنيف لا معرّفاته، فيبقى فارغًا هناك.
  final String? categoryId;
  final String nameAr;
  final String nameEn;
  final String categoryAr;
  final String categoryEn;

  /// slug التصنيف، وهو ما تقرأه قاعدة التوصيات عند الزبون لتعرف هل المنتج من
  /// موسم هذا الطقس. يبقى فارغًا بلا تصنيف، فيخرج من الترشيحات الموسمية.
  final String categorySlug;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? imageUrl;

  /// السعر المطبوع على البطاقة.
  final double price;

  /// السعر المشطوب فوق المطبوع، ولا يوجد إلا حين يكون أعلى منه فعلًا.
  final double? oldPrice;

  /// كيف تملأ الصورة مكانها: قرار محفوظ في صف صورة المنتج عند اللوحة، وهو
  /// نفسه ما يقرأه العميل.
  final BoxFit imageFit;

  String nameFor(AppLanguage language) => language.isArabic ? nameAr : nameEn;

  /// اسم التصنيف وحده، للصفحة التي تعرض الوصف في سطر مستقل ولا تريد مزجهما.
  String categoryFor(AppLanguage language) =>
      (language.isArabic ? categoryAr : categoryEn).trim();

  /// السطر الثاني على البطاقة: التصنيف، والوصف مكانه حين يخلو التصنيف، وهي
  /// القاعدة نفسها في `ProductCard` عند الزبون.
  String secondaryFor(AppLanguage language) {
    final category = categoryFor(language);
    if (category.isNotEmpty) return category;
    return (language.isArabic ? descriptionAr : descriptionEn)?.trim() ?? '';
  }
}
