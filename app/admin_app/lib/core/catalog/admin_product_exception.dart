/// خطأ الكتالوج الذي تصل معالجته إلى المستخدم: الرسالة نصّ جاهز للعرض.
class AdminProductException implements Exception {
  const AdminProductException(this.message);

  final String message;

  @override
  String toString() => message;
}
