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
    this.onOpenOrder,
    this.onOpenProduct,
    required super.child,
  });

  /// يختار قسمًا بمعرّف `AdminDestination` نفسه الذي تستعمله القائمة.
  final void Function(String id) onSelect;

  /// يفتح طلبًا من ملخص اللوحة، إن كان الحساب يملك شاشة الطلبات.
  final ValueChanged<String>? onOpenOrder;

  /// يفتح قائمة المنتجات ببحث الاسم الذي ظهر في ملخص المبيعات.
  final ValueChanged<String>? onOpenProduct;

  /// اليد إن كانت تحت قشرة؛ و`null` خارجها — في اختبار صفحة مفردة أو في
  /// نافذة تُبنى بلا قشرة. من يسمع `null` يخفي رابطه بدل أن يدّعي فعلًا.
  static void Function(String id)? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminNavigator>()?.onSelect;

  static ValueChanged<String>? maybeOpenOrder(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminNavigator>()?.onOpenOrder;

  static ValueChanged<String>? maybeOpenProduct(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AdminNavigator>()
      ?.onOpenProduct;

  @override
  bool updateShouldNotify(AdminNavigator oldWidget) =>
      oldWidget.onSelect != onSelect ||
      oldWidget.onOpenOrder != onOpenOrder ||
      oldWidget.onOpenProduct != onOpenProduct;
}
