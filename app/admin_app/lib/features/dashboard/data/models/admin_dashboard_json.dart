/// أدوات تحويل أجسام استجابة `admin_dashboard_metrics` إلى قيم Dart.
///
/// كل دالة هنا تجيب عن سؤال واحد: «ماذا يقرأ العرض حين يصل الحقل ناقصًا أو
/// بحجم لا يشبه ما توقّع»؟ القاعد أن الغياب صفر أو قائمة فارغة، ما عدا الحقول
/// التي يعني غيابها «حُجزت عنك» فتبقى `null`. والتاريخ الذي لا يُقرأ يُسقَط
/// لا يُختم بطباعة مزيفة، لأن سطرًا بتاريخ وهمي يُقرأ كدليل على حدث لم يقع.
class AdminDashboardJson {
  const AdminDashboardJson._();

  static String text(Object? value) => '${value ?? ''}';

  /// نص فارغ أو `null` يصير غيبة: الاسم المعدود يُطبع فقط إن وُجد.
  static String? nullableText(Object? value) {
    final parsed = text(value).trim();
    return parsed.isEmpty ? null : parsed;
  }

  static int integer(Object? value) => (value as num?)?.toInt() ?? 0;

  static int? nullableInteger(Object? value) => (value as num?)?.toInt();

  static double decimal(Object? value) => (value as num?)?.toDouble() ?? 0;

  static double? nullableDecimal(Object? value) => (value as num?)?.toDouble();

  /// لا علامة تعني «تم» إلا `true` نفسها: غياب الحقل أو نصٌّ غريب يُقرأ
  /// «لم تُفعل»، والخطأ في هذه الجهة يخبر الأدمن بباقي عمل بدل أن يدّعيه.
  static bool boolean(Object? value) => value == true;

  static DateTime? date(Object? value) => DateTime.tryParse(text(value));

  /// يحوّل مصفوفة صفوف ويرمي ما لم يُقرأ منه سطر صالح.
  static List<T> rows<T>(
    Object? value,
    T? Function(Map<String, dynamic> row) build,
  ) {
    if (value is! List) return const <Never>[];
    return List<T>.unmodifiable(
      value
          .whereType<Map>()
          .map((row) => build(Map<String, dynamic>.from(row)))
          .whereType<T>(),
    );
  }
}
