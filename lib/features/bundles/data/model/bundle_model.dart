/// A curated combo (drinks + desserts...) sold for one bundle price.
class BundleModel {
  const BundleModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.productIds,
    required this.price,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<String> productIds;
  final double price;
}
