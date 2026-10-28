/// يوم واحد من الحركة اليومية: تاريخه وماله وعدد طلباته.
///
/// السلسلة تأتي من القاعدة كاملة الثلاثين يومًا، والأيام بلا طلب بصفر حقيقي،
/// حتى يرسم المنحنى انقطاعًا في مكانه بدل أن يقفز فوق يوم فارغ.
class AdminDashboardSalesPoint {
  const AdminDashboardSalesPoint({
    required this.date,
    required this.revenue,
    required this.orders,
  });

  /// منتصف ليل اليوم بتوقيت الرياض كما حسبته القاعدة (`yyyy-MM-dd`).
  final DateTime date;
  final double revenue;
  final int orders;
}
