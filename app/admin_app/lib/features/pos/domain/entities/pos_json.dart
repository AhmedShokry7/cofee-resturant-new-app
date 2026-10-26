List<Map<String, dynamic>> posMaps(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

String posText(Object? value) => value == null ? '' : '$value'.trim();

String? posTextOrNull(Object? value) {
  final text = posText(value);
  return text.isEmpty ? null : text;
}

double posNumber(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? fallback;
}

double? posNumberOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

int posInteger(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? fallback;
}

int? posNullableInteger(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

bool posFlag(Object? value) =>
    value == true || '$value'.toLowerCase() == 'true';

DateTime? posDate(Object? value) {
  final text = posText(value);
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}
