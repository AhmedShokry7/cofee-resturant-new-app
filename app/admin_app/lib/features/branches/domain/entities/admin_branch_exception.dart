/// فشل فعلٍ على فرع برسالة جاهزة للعرض.
class AdminBranchException implements Exception {
  const AdminBranchException(this.message);
  final String message;
  @override
  String toString() => message;
}
