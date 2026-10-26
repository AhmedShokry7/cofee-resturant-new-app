DateTime? loyaltyDate(Object? value) {
  if (value is DateTime) return value;
  if (value == null) return null;
  return DateTime.tryParse('$value');
}

int loyaltyInt(Object? value) => (value as num?)?.toInt() ?? 0;

double loyaltyDouble(Object? value) => (value as num?)?.toDouble() ?? 0;
