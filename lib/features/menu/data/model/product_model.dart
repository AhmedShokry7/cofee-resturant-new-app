class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    this.oldPrice,
    required this.image,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final double price;
  final double? oldPrice;
  final String image;

  bool get hasDiscount => oldPrice != null && oldPrice! > price;
}
