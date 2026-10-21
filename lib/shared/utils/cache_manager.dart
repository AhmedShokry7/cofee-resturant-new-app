/// تخزين مؤقت في ذاكرة الجهاز للبيانات التي لا تتغير كثيراً أثناء جلسة
/// واحدة (المنتجات، الفئات، البانرات، الكوبونات).
///
/// الغرض تجنب إعادة طلب نفس البيانات من Supabase في كل مرة يفتح المستخدم
/// فيها شاشة، ما يقلل عدد الجولات (round trips) والحمل على قاعدة البيانات
/// عندما يتزايد عدد المستخدمين المتزامنين.
///
/// كل إدخال يحمل وقت انتهاء (ttl) ताकि البيانات لا تبقى قديمة إلى الأبد.
class CacheManager {
  CacheManager._();

  static final CacheManager _instance = CacheManager._();

  factory CacheManager() => _instance;

  final Map<String, _CacheEntry<dynamic>> _cache = {};

  /// مدة الصلاحية الافتراضية لكل إدخال (5 دقائق).
  static const Duration defaultTtl = Duration(minutes: 5);

  /// traz البيانات من الكاش إذا كانت موجودة ولم تنتهِ صلاحيتها.
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

  /// يخزن البيانات في الكاش مع مدة صلاحية محددة.
  void set<T>(String key, T value, {Duration? ttl}) {
    _cache[key] = _CacheEntry(
      value: value,
      expiry: DateTime.now().add(ttl ?? defaultTtl),
    );
  }

  /// يزيل إدخالاً معيناً من الكاش.
  void remove(String key) {
    _cache.remove(key);
  }

  /// يزيل جميع البيانات من الكاش (يُستخدم عند تسجيل الخروج أو تغيير اللغة).
  void clear() {
    _cache.clear();
  }

  /// يزيل كل المدخلات التي تبدأ بمفتاح معين (مثل `categories_products_*`).
  void removeWhereStartingWith(String prefix) {
    final keys = _cache.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      _cache.remove(key);
    }
  }

  /// عدد العناصر المخزنة حالياً (لغرض المراقبة/التصحيح).
  int get size => _cache.length;

  ///chéck إذا كان المفتاح موجوداً وساري الصلاحية.
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

/// إدخال واحد في الكاش مع تاريخ انتهاء الصلاحية.
class _CacheEntry<T> {
  const _CacheEntry({required this.value, required this.expiry});

  final T value;
  final DateTime expiry;
}
