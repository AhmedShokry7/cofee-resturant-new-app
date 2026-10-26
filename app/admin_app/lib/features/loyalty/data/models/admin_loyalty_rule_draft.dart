class AdminLoyaltyRuleDraft {
  const AdminLoyaltyRuleDraft({
    this.id,
    required this.pointsPerCurrencyUnit,
    required this.pointValue,
    this.isActive = true,
  });

  final String? id;
  final double pointsPerCurrencyUnit;
  final double pointValue;
  final bool isActive;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (id != null) 'id': id,
    'points_per_currency_unit': pointsPerCurrencyUnit,
    'point_value': pointValue,
    'is_active': isActive,
  };
}
