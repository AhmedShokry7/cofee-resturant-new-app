class BannerModel {
  const BannerModel({
    required this.id,
    required this.image,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.ctaLabel,
    required this.targetCategory,
  });

  final String id;
  final String image;
  final String title;
  final String subtitle;
  final String description;
  final String ctaLabel;
  final String targetCategory;
}
