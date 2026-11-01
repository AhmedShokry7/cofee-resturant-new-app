/// Defensive coercion helpers for values arriving from Postgres.
///
/// Postgres `numeric` is returned by PostgREST as a JSON number *or* a string
/// depending on precision, and money must never be trusted to a raw cast.
/// A malformed price silently becoming 0.0 would be a pricing bug, so every
/// conversion here falls back to the supplied default rather than throwing.
class Db {
  const Db._();

  static String _str(dynamic value, String fallback) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  /// Money and counts. Postgres numeric -> double.
  static double asDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Same as [asDouble] but null-preserving, for optional money columns.
  static double? asDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed;
    }
    return null;
  }

  static int asInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Same as [asInt] but null-preserving, for nullable count columns.
  ///
  /// Needed wherever "no limit" and "a limit of zero" mean different things —
  /// a null `usage_limit` is unlimited, a zero one is never usable.
  static int? asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool asBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      if (v == 'true' || v == 't' || v == '1') return true;
      if (v == 'false' || v == 'f' || v == '0') return false;
    }
    return fallback;
  }

  static String text(dynamic value, [String fallback = '']) =>
      _str(value, fallback);

  /// Optional text: returns null rather than an empty string, so the caller can
  /// tell "absent" from "present but blank".
  static String? textOrNull(dynamic value) {
    if (value == null) return null;
    final s = value is String ? value : value.toString();
    return s.isEmpty ? null : s;
  }

  static List<String> asStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => _str(e, '')).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static Map<String, dynamic> asMap(dynamic value) {
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return const {};
  }
}
