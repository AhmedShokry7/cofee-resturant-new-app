import 'package:supabase_flutter/supabase_flutter.dart';

/// قراءة صفوف من جسور `public` كما يقرأها هذا الفيتشر.
///
/// المستودعان — صفحة المجموعات وحوار المشروب — يسألان الجداول نفسها، فكانت
/// الرحلة الواحدة هنا أولى من نسخةٍ ثانية في كل منهما.
Future<List<Map<String, dynamic>>> bridgeRows(
  SupabaseClient client,
  String table,
  String columns, {
  String? orderedBy,
  String? productId,
}) async {
  final filtered = productId == null
      ? client.from(table).select(columns)
      : client.from(table).select(columns).eq('product_id', productId);
  final rows = orderedBy == null
      ? await filtered
      : await filtered.order(orderedBy);
  return rows
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

/// يجميع صفوفًا تحت قيمة عمود منها، فتُقرأ القيم والربط في رحلة واحدة لكل
/// جدول بدل سؤال مجموعة مجموعة.
Map<String, List<Map<String, dynamic>>> groupRowsBy(
  List<Map<String, dynamic>> rows,
  String column,
) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final row in rows) {
    grouped
        .putIfAbsent('${row[column]}', () => <Map<String, dynamic>>[])
        .add(row);
  }
  return grouped;
}

/// يحدّث الصفّ، وإن لم يجده بعد التحديث يكتبه: المفتاح مركّب (مشروب × خيار)،
/// فلا تعرف اللوحة أيّهما تسبق.
///
/// `select` بعد التحديث هي التي تخبر: ما ترفضه السياسة لا يعيد صفًّا، فيُدرَج
/// صفّ مكانه. أما الإدراج وحده فكان يكرّر صفا موجودا وترفضه 23505.
Future<void> updateThenInsert(
  SupabaseClient client,
  String table, {
  required Map<String, dynamic> match,
  required Map<String, dynamic> values,
  required String returning,
}) async {
  var query = client.from(table).update(values);
  for (final entry in match.entries) {
    query = query.eq(entry.key, entry.value);
  }
  final kept = await query.select(returning);
  if (kept.isNotEmpty) return;
  await client.from(table).insert({...match, ...values});
}
