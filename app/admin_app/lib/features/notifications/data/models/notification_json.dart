int notificationInt(Object? value) => switch (value) {
  final num number => number.toInt(),
  final String text => int.tryParse(text) ?? 0,
  _ => 0,
};

double notificationDouble(Object? value) => switch (value) {
  final num number => number.toDouble(),
  final String text => double.tryParse(text) ?? 0,
  _ => 0,
};

DateTime? notificationDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

String? notificationText(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

Map<String, dynamic>? notificationMap(Object? value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic> notificationPayload(Object? value) {
  final map = notificationMap(value);
  return map == null
      ? const <String, dynamic>{}
      : Map<String, dynamic>.unmodifiable(map);
}
