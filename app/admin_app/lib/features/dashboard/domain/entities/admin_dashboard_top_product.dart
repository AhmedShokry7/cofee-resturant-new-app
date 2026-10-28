/// منتج حسب أسطر الطلبات التي بيعت خلال آخر سبعة أيام.
///
/// الاسم من نسخة السطر وقت البيع لا من الكتالوج الحالي، فالمنتج الذي غيّر اسمه
/// أو حُذف يبقى معروفًا في تقرير ما بيع فعلًا. والصورة كذلك نسخة السطر
/// (`image_snapshot`)، تُرسل `null` حين باع المنتج بلا صورة: صف بلا صورة يُرسم
/// ببدائل الاسم، لا بصورة منتج آخر تُختلق من الكتالوج اليوم.
class AdminDashboardTopProduct {
  const AdminDashboardTopProduct({
    required this.nameAr,
    required this.nameEn,
    required this.quantity,
    required this.revenue,
    this.imageUrl,
  });

  final String nameAr;
  final String nameEn;
  final int quantity;
  final double revenue;
  final String? imageUrl;
}
