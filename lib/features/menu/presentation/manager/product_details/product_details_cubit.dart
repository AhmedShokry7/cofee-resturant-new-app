import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'product_details_state.dart';

class ProductDetailsCubit extends Cubit<ProductDetailsState> {
  ProductDetailsCubit()
      : super(const ProductDetailsState(showFullDescription: false));

  void toggleDescription() {
    emit(
      ProductDetailsState(showFullDescription: !state.showFullDescription),
    );
  }
}
