/// نتيجة فعلٍ على مادة خام (حذف) كما تعيده قاعدة البيانات.
enum InventoryMutationOutcome {
  success,
  notFound,
  hasMovements,
  hasStock,
  inUse,
  permissionDenied,
  failed,
}
