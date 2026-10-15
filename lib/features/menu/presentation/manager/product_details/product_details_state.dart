part of 'product_details_cubit.dart';

@immutable
class ProductDetailsState {
  const ProductDetailsState({
    this.product,
    this.groups = const [],
    this.selection = const OptionSelection.empty(),
    this.estimatedUnitPrice = 0,
    this.resolvedPrice,
    this.quantity = 1,
    this.showFullDescription = false,
    this.isAvailable = true,
    this.unavailableReason,
    this.isLoading = true,
    this.error,
  });

  /// The product as the repository returned it, which carries the branch price
  /// when one applies. Null only while loading or after a load failure.
  final ProductModel? product;

  /// Option groups configured for this product. Empty means the product has no
  /// configurable options, which is normal for food.
  final List<OptionGroup> groups;

  final OptionSelection selection;

  /// Base price plus the chosen deltas, computed locally for an instant update.
  final double estimatedUnitPrice;

  /// Authoritative unit price from resolvePrice. Null until it arrives, and
  /// left null if the call failed.
  final double? resolvedPrice;

  final int quantity;

  final bool showFullDescription;

  /// False when the chosen combination cannot be made at this branch.
  final bool isAvailable;

  final String? unavailableReason;

  final bool isLoading;
  final String? error;

  bool get hasOptions => groups.isNotEmpty;

  /// Blocks adding to the cart until the admin's rules are satisfied.
  String? get validationError => selection.validationError(groups);

  bool get canAddToCart =>
      !isLoading && isAvailable && validationError == null && error == null;

  String get note => selection.note(groups);

  ProductDetailsState copyWith({
    ProductModel? product,
    List<OptionGroup>? groups,
    OptionSelection? selection,
    double? estimatedUnitPrice,
    double? resolvedPrice,
    bool clearResolvedPrice = false,
    int? quantity,
    bool? showFullDescription,
    bool? isAvailable,
    String? unavailableReason,
    bool clearUnavailableReason = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      ProductDetailsState(
        product: product ?? this.product,
        groups: groups ?? this.groups,
        selection: selection ?? this.selection,
        estimatedUnitPrice: estimatedUnitPrice ?? this.estimatedUnitPrice,
        resolvedPrice:
            clearResolvedPrice ? null : (resolvedPrice ?? this.resolvedPrice),
        quantity: quantity ?? this.quantity,
        showFullDescription: showFullDescription ?? this.showFullDescription,
        isAvailable: isAvailable ?? this.isAvailable,
        unavailableReason: clearUnavailableReason
            ? null
            : (unavailableReason ?? this.unavailableReason),
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}