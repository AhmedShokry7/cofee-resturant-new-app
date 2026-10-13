import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/menu/data/menu_list.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

part 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit() : super(SearchState(query: "", results: getMenuList()));

  void search(String query) {
    final keyword = query.trim().toLowerCase();
    final results = keyword.isEmpty
        ? getMenuList()
        : getMenuList()
              .where(
                (product) =>
                    product.name.toLowerCase().contains(keyword) ||
                    product.description.toLowerCase().contains(keyword) ||
                    product.category.toLowerCase().contains(keyword),
              )
              .toList();
    emit(SearchState(query: query, results: results));
  }
}
