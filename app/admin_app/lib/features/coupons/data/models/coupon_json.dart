DateTime? couponDate(Object? value) {
  if (value is DateTime) return value;
  if (value == null) return null;
  return DateTime.tryParse('$value');
}

int couponInt(Object? value) => (value as num?)?.toInt() ?? 0;

double couponDouble(Object? value) => (value as num?)?.toDouble() ?? 0;

int? couponNullableInt(Object? value) => (value as num?)?.toInt();

double? couponNullableDouble(Object? value) => (value as num?)?.toDouble();
