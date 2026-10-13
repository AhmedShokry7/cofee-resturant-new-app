class CouponModel {
  const CouponModel({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.discount,
  });

  final String id;
  final String code;
  final String title;
  final String description;
  final String discount;
}
