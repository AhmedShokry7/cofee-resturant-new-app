/// In-memory cache for data that barely moves during a session: products,
/// categories, banners, coupons.
///
/// Its purpose is to avoid asking Supabase for the same rows every time a
/// screen opens, which cuts the round trips and the load on the database as
/// concurrent customers grow.
///
/// Every entry carries an expiry ([defaultTtl]) so nothing stays served after
/// the admin changed it.
class CacheManager {
  CacheManager._();

  static final CacheManager _instance = CacheManager._();

  factory CacheManager() => _instance;

  final Map<String, _CacheEntry<dynamic>> _cache = {};

  /// How long an entry is served to everyone (5 minutes).
  static const Duration defaultTtl = Duration(minutes: 5);

  /// The cached value for [key], or null when it was never stored or has
  /// expired.
  T? get<T>(String key, {Duration? ttl}) {
    final entry = _cache[key];
    if (entry == null) return null;
    final expiry = entry.expiry;
    if (expiry.isBefore(DateTime.now())) {
      _cache.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  /// Stores [value] under [key] with the expiry it is served for.
  void set<T>(String key, T value, {Duration? ttl}) {
    _cache[key] = _CacheEntry(
      value: value,
      expiry: DateTime.now().add(ttl ?? defaultTtl),
    );
  }

  /// Drops one entry.
  void remove(String key) {
    _cache.remove(key);
  }

  /// Drops everything (used on sign-out and on a language change, because both
  /// invalidate what the customer was shown).
  void clear() {
    _cache.clear();
  }

  /// Drops every key starting with [prefix], such as `categories_products_*`.
  void removeWhereStartingWith(String prefix) {
    final keys = _cache.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      _cache.remove(key);
    }
  }

  /// How many entries are held right now (for diagnostics).
  int get size => _cache.length;

  /// Whether [key] holds a value that has not expired.
  bool contains(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    if (entry.expiry.isBefore(DateTime.now())) {
      _cache.remove(key);
      return false;
    }
    return true;
  }
}

/// One cached value and the moment it stops being served.
class _CacheEntry<T> {
  const _CacheEntry({required this.value, required this.expiry});

  final T value;
  final DateTime expiry;
}
