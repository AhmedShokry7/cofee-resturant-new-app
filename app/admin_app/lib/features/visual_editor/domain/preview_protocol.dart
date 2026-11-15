/// عقد قناة المعاينة بين لوحة الأدمن وتطبيق العميل داخل الإطار.
///
/// هذا الملف نقي بلا اعتماديات ويب حتى يُختبر على المحرك مباشرة: التحقق من
/// مصدر الرسالة وجلستها، والطابور الذي يحفظ الرسائل قبل جاهزية المعاينة
/// ثم يصرفها بالترتيب، وحالات الاتصال الأربع.
library;

import 'dart:async';
import 'dart:convert';

/// حالات الاتصال بالمحاكي كما يراها الموظف.
enum PreviewConnection {
  /// الإطار يحمّل تطبيق العميل ولم تعلن جاهزيتها بعد.
  connecting,

  /// المعاينة بثّت PREVIEW_READY والقناة حيّة في الاتجاهين.
  connected,

  /// كانت متصلة ثم صمت — بانتظار إشارة حياة أو يد الموظف.
  disconnected,

  /// فشل واضح: انتهت محاولات إعادة الاتصال، أو وصل خطأ من المعاينة.
  error,
}

/// هل تُقبل رسالة واردة من الإطار؟
///
/// القاعدة: المصدر يجب أن يكون تطبيق العميل نفسه (origin رابط الإطار، لا
/// origin الأدمن)، والجلسة يجب أن تطابق جلسة الرابط. غياب أيٍّ منهما رفض،
/// فلا أمر من مصدر مجهول يرسم في المعاينة ولا حالة مزيفة في المحرر.
bool isPreviewMessageAllowed({
  required Object? senderOrigin,
  required String? expectedOrigin,
  required Object? data,
  String? expectedSessionId,
}) {
  if (expectedOrigin == null || expectedOrigin.isEmpty) return false;
  if (senderOrigin is! String || senderOrigin.isEmpty) return false;
  // المقارنة على الأصل الكامل: ميثاق وخوم ومنفذ معًا — localhost:5000 لا
  // يقبل ما يدّعي أنه 127.0.0.1:5000، فالفرق المنفذ فرق مصدر.
  if (senderOrigin != expectedOrigin) return false;
  if (data is! Map) return false;
  if (expectedSessionId == null) return false;
  return data['sessionId'] == expectedSessionId;
}

/// فكّ حمولة الرسالة الواردة: الطرفان يرسلان نص JSON (toJSONString)، والمتصفح
/// يسلّمه Dart كسلسلة — من يقرأ `is Map` فقط يسقط كل ما يصل. النقي هنا
/// يُختبر على المحرك: نص صالح يُفكّ، نص تالف وخريطة وغيرهما تعود null.
Map<String, dynamic>? decodePreviewPayload(Object? raw) {
  Object? decoded = raw;
  if (raw is String) {
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
  if (decoded is! Map) return null;
  return Map<String, dynamic>.from(decoded);
}

/// origin رابط المعاينة (origin تطبيق العميل) من الرابط الكامل.
///
/// الأدمن يرسل *إلى* هذا الأصل، ويقبل الوارد *منه* — لا من أصله هو.
String? previewOriginOf(String? previewUrl) {
  if (previewUrl == null || previewUrl.isEmpty) return null;
  final uri = Uri.tryParse(previewUrl);
  if (uri == null) return null;
  try {
    // أصل غير http(s) (نص غير رابط، أو مخطط بلا سلطة) لا يصلح قناة معاينة.
    return uri.origin;
  } catch (_) {
    return null;
  }
}

/// طابور الرسائل الصادرة قبل جاهزية المعاينة.
///
/// كل رسالة تحرير تُقبض هنا ما دام الإطار لم يعلن جاهزيته، فلا تعديل
/// يضيع أثناء تحميل تطبيق العميل. عند PREVIEW_READY تُصرف بالترتيب الذي
/// وُلدت به، ثم تمر الرسائل الجديدة مباشرة.
class PreviewOutboundQueue<T> {
  final List<T> _items = [];
  bool _ready = false;

  bool get isReady => _ready;
  int get length => _items.length;

  /// إعلان الجاهزية: يعيد true إن كان هناك ما يُصرف.
  bool markReady() {
    final hadPending = _items.isNotEmpty;
    _ready = true;
    return hadPending;
  }

  /// إضافة رسالة: تُصرف فورًا إن كانت القناة جاهزة، وإلا تنتظر بالطابور.
  /// تعيد true إن كان على المستدعي الإرسال الآن.
  bool offer(T message) {
    if (_ready) return true;
    _items.add(message);
    return false;
  }

  /// سحب الرسائل المعلقة بالترتيب وإفراغ الطابور.
  List<T> drain() {
    final drained = List<T>.of(_items);
    _items.clear();
    return drained;
  }

  /// إعادة تعيين بعد إعادة تحميل الإطار: الطابور يبقى (آخر مستند يظل
  /// محفوظًا في آخر رسالة)، والجاهزية تسقط حتى تعلن المعاينة الجديدة
  /// جاهزيتها.
  void reset({bool keepPending = true}) {
    _ready = false;
    if (!keepPending) _items.clear();
  }

  /// إفراغ كامل دون تغيير الجاهزية.
  void clear() => _items.clear();
}

/// ساعة الانقطاع: تُقفل بعد المهلة دون إشارة حياة.
class PreviewWatchdog {
  PreviewWatchdog({
    required this.onExpired,
    this.timeout = const Duration(seconds: 45),
  });

  final void Function() onExpired;
  final Duration timeout;
  Timer? _timer;

  void arm() {
    disarm();
    _timer = Timer(timeout, onExpired);
  }

  void disarm() {
    _timer?.cancel();
    _timer = null;
  }
}
