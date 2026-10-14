part of 'product_details_cubit.dart';

@immutable
class ProductDetailsState {
  const ProductDetailsState({
    required this.showFullDescription,
    this.size = DrinkSize.medium,
    this.sugar = SugarLevel.normal,
    this.extraIds = const {},
    this.quantity = 1,
  });

  final bool showFullDescription;
  final DrinkSize size;
  final SugarLevel sugar;
  final Set<String> extraIds;
  final int quantity;

  ProductDetailsState copyWith({
    bool? showFullDescription,
    DrinkSize? size,
    SugarLevel? sugar,
    Set<String>? extraIds,
    int? quantity,
  }) {
    return ProductDetailsState(
      showFullDescription: showFullDescription ?? this.showFullDescription,
      size: size ?? this.size,
      sugar: sugar ?? this.sugar,
      extraIds: extraIds ?? this.extraIds,
      quantity: quantity ?? this.quantity,
    );
  }
}
