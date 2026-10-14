import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/menu/data/product_variants.dart';

part 'product_details_state.dart';

class ProductDetailsCubit extends Cubit<ProductDetailsState> {
  ProductDetailsCubit()
      : super(const ProductDetailsState(showFullDescription: false));

  void toggleDescription() {
    emit(state.copyWith(showFullDescription: !state.showFullDescription));
  }

  void selectSize(DrinkSize size) {
    emit(state.copyWith(size: size));
  }

  void selectSugar(SugarLevel sugar) {
    emit(state.copyWith(sugar: sugar));
  }

  void toggleExtra(String extraId) {
    final ids = {...state.extraIds};
    if (ids.contains(extraId)) {
      ids.remove(extraId);
    } else {
      ids.add(extraId);
    }
    emit(state.copyWith(extraIds: ids));
  }

  void incrementQuantity() {
    if (state.quantity < 99) emit(state.copyWith(quantity: state.quantity + 1));
  }

  void decrementQuantity() {
    if (state.quantity > 1) emit(state.copyWith(quantity: state.quantity - 1));
  }
}
