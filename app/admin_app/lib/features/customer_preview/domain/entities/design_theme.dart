import 'dart:convert';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/customer_preview/domain/registry/design_property.dart';

/// طبقة الشكل العام لتطبيق العميل داخل مستند التصميم.
///
/// overrides لا صورة كاملة: الدور الغائب يعني «دع ما عند الزبون كما هو»، فلا
/// يُنشر شكل لم يره أحد لمجرد أن الموظف لمس خانة أخرى. هذا هو الضمان أن تصميم
/// اليوم هو التصميم عند بدء النظام، وأن الإرجاع إلى الأصلي مسألة حذف سطر لا
/// تذكّر قيم.
///
/// المستند يحمل الأسماء لا الأرقام: القياسات تعيش في نظام تصميم العميل، فتغيير
/// مقياس في اللوحة لا يعني رقمًا حرًا على شاشة الزبون.
class DesignTheme {
  const DesignTheme({
    this.colors = const <DesignColorRole, String>{},
    this.textScale = DesignScale.defaultKey,
    this.radiusScale = DesignScale.defaultKey,
  });

  /// لا طبقة: كل دور يرث قيمة العميل، وكل مقياس على حاله.
  static const DesignTheme none = DesignTheme();

  final Map<DesignColorRole, String> colors;

  /// مفتاح مقياس الخط من [DesignScale.textKeys].
  final String textScale;

  /// مفتاح مقياس نصف القطر من [DesignScale.radiusKeys].
  final String radiusScale;

  bool get isDefault =>
      colors.isEmpty &&
      textScale == DesignScale.defaultKey &&
      radiusScale == DesignScale.defaultKey;

  /// هل بقي شيء يخالف ما يراه الزبون اليوم؟ تعرض اللوحة هذا الجواب قبل النشر.
  bool get isChanged => !isDefault;

  /// اللون وحده يتغيّر، وبقية الأدوار كما كانت: الطبقة تُبنى دورًا دورًا لأن
  /// الموظف يلوّن شاشة لا يستورد شاشة أخرى.
  DesignTheme withColor(DesignColorRole role, String hex) {
    final next = Map<DesignColorRole, String>.of(colors);
    next[role] = hex.toUpperCase();
    return DesignTheme(
      colors: next,
      textScale: textScale,
      radiusScale: radiusScale,
    );
  }

  /// حذف Override: الدور يرجع لقيمة العميل، لا لأسود ولا لرمادي من عند اللوحة.
  DesignTheme withoutColor(DesignColorRole role) {
    if (!colors.containsKey(role)) return this;
    final next = Map<DesignColorRole, String>.of(colors)..remove(role);
    return DesignTheme(
      colors: next,
      textScale: textScale,
      radiusScale: radiusScale,
    );
  }

  DesignTheme withTextScale(String key) => DesignTheme(
    colors: colors,
    textScale: key,
    radiusScale: radiusScale,
  );

  DesignTheme withRadiusScale(String key) => DesignTheme(
    colors: colors,
    textScale: textScale,
    radiusScale: key,
  );

  Map<String, Object?> toMap() {
    if (isDefault) return const <String, Object?>{};
    return <String, Object?>{
      if (colors.isNotEmpty)
        'colors': <String, Object?>{
          for (final entry in colors.entries) entry.key.key: entry.value,
        },
      if (textScale != DesignScale.defaultKey) 'text_scale': textScale,
      if (radiusScale != DesignScale.defaultKey) 'radius_scale': radiusScale,
    };
  }

  /// الطبقة جزء اختياري من المستند: غياب مفتاح `theme` كله طبقة محايدة، لأن
  /// مستندات النسخة الأولى لم تحمل شكلًا أصلًا.
  static DesignTheme fromMap(Object? raw) {
    if (raw == null) return none;
    if (raw is! Map<Object?, Object?>) {
      throw const FormatException('طبقة الشكل ليست كائنًا');
    }
    // مفتاح لا يعرفه المحرّر يُرفض هنا كما ترفضه القاعدة: لو تُرك، كانت اللوحة
    // تعرض طبقة سليمة ثم تنشر مستندًا ترفضه القاعدة برسالة لا تُفهم.
    for (final key in raw.keys) {
      if (key != 'colors' && key != 'text_scale' && key != 'radius_scale') {
        throw FormatException('مفتاح في طبقة الشكل لا يعرفه المحرّر: $key');
      }
    }
    final colors = <DesignColorRole, String>{};
    final rawColors = raw['colors'];
    if (rawColors != null) {
      if (rawColors is! Map<Object?, Object?>) {
        throw const FormatException('ألوان الطبقة ليست كائنًا');
      }
      for (final entry in rawColors.entries) {
        final role = DesignColorRole.ofKey(entry.key as String?);
        if (role == null) {
          throw FormatException('دور لون لا يعرفه المحرّر: ${entry.key}');
        }
        final value = entry.value;
        if (value is! String || !DesignTheme.isHexColor(value)) {
          throw FormatException('لون الدور ${role.key} ليس #RRGGBB');
        }
        colors[role] = value.toUpperCase();
      }
    }
    final textScale = _scale(raw['text_scale'], DesignScale.textKeys);
    final radiusScale = _scale(raw['radius_scale'], DesignScale.radiusKeys);
    return DesignTheme(
      colors: colors,
      textScale: textScale,
      radiusScale: radiusScale,
    );
  }

  static String _scale(Object? raw, Set<String> allowed) {
    if (raw == null) return DesignScale.defaultKey;
    if (raw is! String || !allowed.contains(raw)) {
      throw FormatException('مقياس غير معروف: $raw');
    }
    return raw;
  }

  /// `#RRGGBB` أو `#AARRGGBB` بأحرف ست عشرية، لا اسم لون ولا قيمة Dart.
  static bool isHexColor(String value) =>
      RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(value);
}

/// أدوار الألوان التي يملكها مستند التصميم.
///
/// كل دور هنا له موضع واحد على الأقل في شاشة الزبون؛ لا دور يزيّن اللوحة فقط.
/// النص يقرأ العربية في اللوحة العربية والإنجليزية في غيرها، والمفتاح هو ما
/// يُطبع في المستند.
enum DesignColorRole {
  primary('primary', 'اللون الأساسي', 'Primary'),
  secondary('secondary', 'اللون الثانوي', 'Secondary'),
  background('background', 'خلفية الصفحات', 'Background'),
  surface('surface', 'سطح البطاقات', 'Surface'),
  textPrimary('text_primary', 'النصوص الأساسية', 'Text primary'),
  textSecondary('text_secondary', 'النصوص الثانوية', 'Text secondary'),
  border('border', 'الحدود', 'Border'),
  success('success', 'لون النجاح', 'Success'),
  error('error', 'لون الخطأ', 'Error'),
  disabled('disabled', 'العناصر المعطّلة', 'Disabled');

  const DesignColorRole(this.key, this.labelAr, this.labelEn);

  final String key;
  final String labelAr;
  final String labelEn;

  String label(AppLanguage language) =>
      language.isArabic ? labelAr : labelEn;

  static DesignColorRole? ofKey(String? key) {
    for (final role in DesignColorRole.values) {
      if (role.key == key) return role;
    }
    return null;
  }
}

/// مفاتيح المقاييس التي يقدّمها المحرّر، وأسماء تُترجم عند الرسم.
///
/// الأرقام نفسها في العميل: `default` تعني «لا مضاعف»، وهي القيمة التي كان
/// عليها التطبيق قبل النظام.
abstract final class DesignScale {
  DesignScale._();

  static const String defaultKey = 'default';

  static const Set<String> textKeys = <String>{
    defaultKey,
    'compact',
    'comfortable',
    'large',
  };

  static const Set<String> radiusKeys = <String>{
    defaultKey,
    'sharp',
    'soft',
    'round',
    'pill',
  };

  static const Map<String, L10nText> textLabels = <String, L10nText>{
    defaultKey: L10nText('افتراضي', 'Default'),
    'compact': L10nText('نصوص أصغر', 'Compact'),
    'comfortable': L10nText('نصوص مريحة', 'Comfortable'),
    'large': L10nText('نصوص كبيرة', 'Large'),
  };

  static const Map<String, L10nText> radiusLabels = <String, L10nText>{
    defaultKey: L10nText('افتراضي', 'Default'),
    'sharp': L10nText('حواف حادّة', 'Sharp'),
    'soft': L10nText('حواف ناعمة', 'Soft'),
    'round': L10nText('حواف دائرية', 'Round'),
    'pill': L10nText('كبسولة', 'Pill'),
  };

  static String label(String key, AppLanguage language, bool text) =>
      (text ? textLabels[key] : radiusLabels[key])?.of(language) ?? key;

  /// مضاعفات الخط: عقد المستند تحمل الاسم، وهذه هي الأرقام التي يرسم بها الاسم.
  ///
  /// `default` هو 1 حرفيًا: المستند الذي لم يغيّر مقياسًا يرسم بخطوط التطبيق
  /// نفسها، لا بخطوط اختارتها اللوحة. والقيم نفسها في قارئ العميل، فاسم المقياس
  /// عقد بين اللوحة والشاشة لا ذكرى في كليهما.
  static const Map<String, double> textFactors = <String, double>{
    defaultKey: 1,
    'compact': 0.9,
    'comfortable': 1.05,
    'large': 1.15,
  };

  static double textFactor(String key) => textFactors[key] ?? 1;
}

/// مقارنة طبقتين بالمحتوى، لزر «رجوع» يعرض متى كان الفرق حقيقيًا.
bool sameTheme(DesignTheme a, DesignTheme b) =>
    jsonEncode(a.toMap()) == jsonEncode(b.toMap());
