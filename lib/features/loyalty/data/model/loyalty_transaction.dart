/// One loyalty wallet movement. Positive = earned, negative = spent.
class LoyaltyTransaction {
  const LoyaltyTransaction({
    required this.id,
    required this.title,
    required this.points,
    required this.date,
  });

  final String id;
  final String title;
  final int points;
  final DateTime date;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'points': points,
    'date': date.toIso8601String(),
  };

  static LoyaltyTransaction? fromJson(dynamic value) {
    if (value is! Map) return null;
    try {
      return LoyaltyTransaction(
        id: value['id']?.toString() ?? '',
        title: value['title']?.toString() ?? '',
        points: (value['points'] as num?)?.toInt() ?? 0,
        date:
            DateTime.tryParse(value['date']?.toString() ?? '') ??
            DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}
