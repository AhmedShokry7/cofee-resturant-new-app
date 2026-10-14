import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'categories_state.dart';

class CategoriesCubit extends Cubit<CategoriesState> {
  CategoriesCubit() : super(const CategoriesState(index: 0));

  void select(int index) {
    if (index == state.index) return;
    emit(CategoriesState(index: index));
  }
}
