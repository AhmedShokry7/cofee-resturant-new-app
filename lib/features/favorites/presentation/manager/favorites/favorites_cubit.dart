import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'favorites_state.dart';

class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit() : super(const FavoritesState(ids: {}));

  void toggle(String productId) {
    final ids = {...state.ids};
    if (!ids.add(productId)) {
      ids.remove(productId);
    }
    emit(FavoritesState(ids: ids));
  }
}
