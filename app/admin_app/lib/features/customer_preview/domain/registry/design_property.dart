import 'package:admin_app/core/locale/app_locale.dart';

/// نص ثنائي اللغة لتسميات المحرّر.
///
/// السكة والمكتبة وشجرة المكونات ولوحة الخصائص تتبع لغة اللوحة، بينما يتبع
/// الهاتف داخلها لغة المعاينة — فالأسماء هنا ليست أسماء شاشة الزبون التي يردها
/// `SimulatorLabels`. نفس سابق التسميتين في تلك الشاشة، بلا تفريخ ملف تسميات
/// ثالث.
class L10nText {
  const L10nText(this.ar, this.en);

  final String ar;
  final String en;

  String of(AppLanguage language) => language.isArabic ? ar : en;

  @override
  String toString() => ar;
}

/// أنواع القيم التي يقبلها المستند، وهي أنواع JSON حرفيًا لا أصناف Dart.
enum DesignPropertyKind {
  /// نص يكتبه الموظف، ولا يُقبل فارغًا.
  text,

  /// علم صحيح/خطأ.
  toggle,

  /// عدد صحيح داخل حدّين يحدّدهما المكوّن نفسه.
  count,

  /// اسم توكن هندسي من توكنات اللوحة، ولا رقم حر: رقم حر في مستند منشور يعني
  /// شاشة لم يرها أحد.
  token,

  /// خيار من قائمة يحددها المكوّن.
  choice,

  /// مفتاح مصدر بيانات من [DataSourceRegistry].
  dataSource,

  /// مفتاح إجراء من [ActionRegistry].
  action,

  /// معرّف تصنيف يُختار من التصنيفات المقروءة، لا نص حر.
  categoryReference,

  /// معرّف منتج يُختار من المنتجات المقروءة.
  productReference,
}

/// خاصية واحدة قابلة للتحرير على مكوّن.
///
/// الحدّ الأدنى والحدّ الأقصى والقيمة الافتراضية قرار المطوّر؛ الموظف لا يكتب
/// رقمًا خارجها والمحظور لا يصل إلى المستند أصلًا.
class DesignPropertySpec {
  const DesignPropertySpec({
    required this.key,
    required this.label,
    required this.kind,
    required this.defaultValue,
    this.min,
    this.max,
    this.choices = const <String>[],
    this.choiceLabels = const <String, L10nText>{},
    this.optional = false,
  });

  final String key;
  final L10nText label;
  final DesignPropertyKind kind;
  final Object? defaultValue;

  final int? min;
  final int? max;

  /// القيم المقبولة لنوعي token وchoice.
  final List<String> choices;

  /// تسميات اختيارية للقيم المطبوعة في القائمة (مفتاح → نص عربي/إنجليزي).
  final Map<String, L10nText> choiceLabels;

  /// خاصية لا قيمة لها إطلاقًا: تُترك في المستند غائبة لا فارغة.
  final bool optional;

  String choiceLabel(String value, AppLanguage language) =>
      choiceLabels[value]?.of(language) ?? value;

  /// سبب رفض القيمة، أو null حين تكون صالحة.
  String? reject(Object? value) {
    if (value == null) return optional ? null : 'مفقودة';
    switch (kind) {
      case DesignPropertyKind.text:
        if (value is! String) return 'نص مطلوب';
        // نص اختياري فارغ يعني «لا يُطبع»، لا «يُطبع فراغ».
        if (value.trim().isEmpty) return optional ? null : 'نص مطلوب';
        return null;
      case DesignPropertyKind.toggle:
        return value is bool ? null : 'علم مطلوب';
      case DesignPropertyKind.count:
        if (value is! int) return 'عدد صحيح مطلوب';
        if (min != null && value < min!) return 'أقل من الحدّ';
        if (max != null && value > max!) return 'أكبر من الحدّ';
        return null;
      case DesignPropertyKind.token:
      case DesignPropertyKind.choice:
      case DesignPropertyKind.dataSource:
      case DesignPropertyKind.action:
        if (value is! String) return 'قيمة نصية مطلوبة';
        return choices.contains(value) ? null : 'قيمة غير مسموحة';
      case DesignPropertyKind.categoryReference:
      case DesignPropertyKind.productReference:
        return value is String && value.isNotEmpty ? null : 'معرّف مطلوب';
    }
  }
}
