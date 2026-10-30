/// قراءات JSON المشتركة بين كيانات HR.
///
/// القاعدة ترسل المال `numeric`، فتصل أحيانًا رقمًا وأحيانًا نصًا حسب التحويل
/// في jsonb؛ والسطر الواحد هنا يمنع أن يقرأ كل كوتشنر المال بطريقته فيختلف
/// ما تعرضه شاشة على ما تعرضها شاشة أخرى.
library;

double hrNum(Object? value) => switch (value) {
  null => 0,
  final num number => number.toDouble(),
  final String text => double.tryParse(text.replaceAll(',', '')) ?? 0,
  _ => 0,
};

int hrInt(Object? value) => switch (value) {
  null => 0,
  final int number => number,
  final num number => number.round(),
  final String text => int.tryParse(text) ?? 0,
  _ => 0,
};

bool hrBool(Object? value) => value == true || value == 'true';

String hrText(Object? value) => value == null ? '' : '$value';

String? hrNullText(Object? value) {
  final text = value == null ? '' : '$value'.trim();
  return text.isEmpty ? null : text;
}

DateTime? hrDate(Object? value) => switch (value) {
  null => null,
  final DateTime date => date,
  final String text => DateTime.tryParse(text),
  _ => null,
};

Map<String, dynamic> hrMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> hrMaps(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false)
    : const <Map<String, dynamic>>[];

/// المعرّف كما ترسله القاعدة: uuid نصًا، أو null حين لا صف بعد.
String? hrId(Object? value) => hrNullText(value);
