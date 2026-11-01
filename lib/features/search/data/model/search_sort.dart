import 'package:new_coffee/core/locale/app_strings.dart';

enum SearchSort {
  relevance,
  priceLowHigh,
  priceHighLow,
  nameAsc;

  /// Display label in the app language. Read at build time so a language
  /// toggle re-renders it with everything else.
  String get label => switch (this) {
    SearchSort.relevance => S.sortRelevance,
    SearchSort.priceLowHigh => S.sortPriceLow,
    SearchSort.priceHighLow => S.sortPriceHigh,
    SearchSort.nameAsc => S.sortName,
  };
}
