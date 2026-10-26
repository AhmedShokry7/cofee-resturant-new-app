import 'dart:typed_data';

/// جسر محاكي أندرويد الذي تعرض له شاشة المعاينة: لا تعرف الطبقات العليا شيئًا
/// عن `http` ولا عن العنوان المحلي، بل تتعامل مع هذه الأوامر فقط.
abstract interface class EmulatorBridge {
  /// يفحص ارتباط الجسر بالجهاز.
  Future<bool> check(String token);

  /// يلتقط صورة الشاشة الحالية.
  Future<Uint8List> screenshot(String token);

  /// يضغط نقطة على الشاشة.
  Future<void> tap(String token, int x, int y);

  /// يسحب من نقطة إلى نقطة خلال مدة.
  Future<void> swipe(
    String token,
    int x1,
    int y1,
    int x2,
    int y2,
    int duration,
  );

  /// يرسل مفتاح جهازًا مثل رجوع أو الرئيسية.
  Future<void> key(String token, String key);

  /// يطلب إعادة تحميل تطبيق الزبون داخل المحاكي.
  Future<void> refresh(String token);

  /// يكتب نصًا في حقل التركيز داخل المحاكي.
  Future<void> sendText(String token, String value);

  /// يغلق عميل الشبكة الذي يملكه هذا الجسر.
  void dispose();
}
