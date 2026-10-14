import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/assistant/data/assistant_language.dart';
import 'package:new_coffee/features/assistant/data/assistant_phrases.dart';
import 'package:new_coffee/features/menu/data/menu_list.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/search/data/model/search_sort.dart';

part 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit()
      : super(
          SearchState(
            query: "",
            sort: SearchSort.relevance,
            results: getMenuList(),
          ),
        );

  void search(String query) => _emit(
    query: query,
    sort: state.sort,
    category: state.category,
    minPrice: state.minPrice,
    maxPrice: state.maxPrice,
  );

  void applyFilters({
    required SearchSort sort,
    String? category,
    double? minPrice,
    double? maxPrice,
  }) => _emit(
    query: state.query,
    sort: sort,
    category: category,
    minPrice: minPrice,
    maxPrice: maxPrice,
  );

  void resetFilters() => _emit(
    query: state.query,
    sort: SearchSort.relevance,
    category: null,
    minPrice: null,
    maxPrice: null,
  );

  void _emit({
    required String query,
    required SearchSort sort,
    required String? category,
    required double? minPrice,
    required double? maxPrice,
  }) {
    final keyword = normalizeText(query);
    // Same Arabic vocabulary the assistant understands (شاي -> tea...).
    final synonymsHit = <String>{};
    var coffeeTalk = false;
    if (keyword.isNotEmpty) {
      for (final entry in AssistantPhrases.productSynonyms.entries) {
        final synonym = normalizeText(entry.key);
        if (synonym.length > 2 && keyword.contains(synonym)) {
          if (entry.value == 'coffee') {
            coffeeTalk = true;
          } else {
            synonymsHit.add(entry.value.toLowerCase());
          }
        }
      }
    }
    final results = getMenuList().where((product) {
      final name = normalizeText(product.name);
      final description = normalizeText(product.description);
      final normalizedCategory = normalizeText(product.category);
      final matchesQuery =
          keyword.isEmpty ||
          name.contains(keyword) ||
          description.contains(keyword) ||
          normalizedCategory.contains(keyword) ||
          synonymsHit.any(name.contains) ||
          (coffeeTalk && normalizedCategory.contains('coffee'));
      final matchesCategory = category == null || product.category == category;
      final matchesPrice =
          (minPrice == null || product.price >= minPrice) &&
          (maxPrice == null || product.price <= maxPrice);
      return matchesQuery && matchesCategory && matchesPrice;
    }).toList();

    switch (sort) {
      case SearchSort.priceLowHigh:
        results.sort((a, b) => a.price.compareTo(b.price));
      case SearchSort.priceHighLow:
        results.sort((a, b) => b.price.compareTo(a.price));
      case SearchSort.nameAsc:
        results.sort((a, b) => a.name.compareTo(b.name));
      case SearchSort.relevance:
        break;
    }

    emit(
      SearchState(
        query: query,
        sort: sort,
        category: category,
        minPrice: minPrice,
        maxPrice: maxPrice,
        results: results,
      ),
    );
  }
}
