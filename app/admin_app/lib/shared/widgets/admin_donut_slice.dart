import 'package:flutter/material.dart';

/// قطعة واحدة في رسم الدونات: تسمية للدلالة وقيمة غير سالبة ولون.
///
/// التسمية لا تُرسم داخل الرسم: الدونات تكتفي بشكل النسبة، والأسماء تبقى في
/// مفتاح الألوان تحتها حتى تُقرأ عربيًا وإنجليزيًا دون ازدحام القوس.
class AdminDonutSlice {
  const AdminDonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  /// اسم القطعة، يُستعمل مفتاحًا ودلالةً خارج الرسم.
  final String label;

  /// قيمة القطعة؛ تُوزَّع الحلقات بحسب نسبتها من مجموع القيم.
  final double value;

  /// لون القوس الخاص بالقطعة.
  final Color color;
}
