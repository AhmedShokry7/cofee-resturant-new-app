import 'package:new_coffee/core/locale/app_locale.dart';

enum SearchSort {
  relevance,
  priceLowHigh,
  priceHighLow,
  nameAsc;

  /// Display label in the app language. Read at build time so a language
  /// toggle re-renders it with everything else.
  String get label {
    final ar = AppLocale.instance.isArabic;
    return switch (this) {
      SearchSort.relevance => ar ? 'الأكثر صلة' : 'Relevance',
      SearchSort.priceLowHigh => ar ? 'السعر: من الأقل' : 'Price: Low',
      SearchSort.priceHighLow => ar ? 'السعر: من الأعلى' : 'Price: High',
      SearchSort.nameAsc => ar ? 'الاسم' : 'Name',
    };
  }
}
