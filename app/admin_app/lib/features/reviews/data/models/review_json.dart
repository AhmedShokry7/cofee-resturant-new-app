int reviewInt(Object? value) => switch (value) {
  final num number => number.toInt(),
  final String text => int.tryParse(text) ?? 0,
  _ => 0,
};

double reviewDouble(Object? value) => switch (value) {
  final num number => number.toDouble(),
  final String text => double.tryParse(text) ?? 0,
  _ => 0,
};

DateTime? reviewDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

String? reviewText(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

Map<String, dynamic>? reviewMap(Object? value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}
