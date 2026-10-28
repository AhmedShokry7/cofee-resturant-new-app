import 'package:flutter/widgets.dart';

/// يوصل قرار «اذهب إلى قسم آخر» إلى داخل الصفحة نفسها.
///
/// القسم يُختار بمعرّف في `AdminShell` لا بمسار، فكانت الأزرار التي تعدو من
/// لوحة التحكم إلى الطلبات تُختلق سلوكًا لا تملكه. هنا يعير القشرة يدها
/// لمن تحتها، وتبقى القائمة الجانبية هي من ينفّذ: لا صفحة تعرف قائمة، ولا
/// ممرّ ينسخ قرار التنقّل.
class AdminNavigator extends InheritedWidget {
  const AdminNavigator({
    super.key,
    required this.onSelect,
    required super.child,
  });

  /// يختار قسمًا بمعرّف `AdminDestination` نفسه الذي تستعمله القائمة.
  final void Function(String id) onSelect;

  /// اليد إن كانت تحت قشرة؛ و`null` خارجها — في اختبار صفحة مفردة أو في
  /// نافذة تُبنى بلا قشرة. من يسمع `null` يخفي رابطه بدل أن يدّعي فعلًا.
  static void Function(String id)? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminNavigator>()?.onSelect;

  @override
  bool updateShouldNotify(AdminNavigator oldWidget) =>
      oldWidget.onSelect != onSelect;
}
