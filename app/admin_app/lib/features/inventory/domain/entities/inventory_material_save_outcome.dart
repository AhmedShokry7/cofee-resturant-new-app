/// نتيجة حفظ مادة خام كما تعيدها قاعدة البيانات.
enum InventoryMaterialSaveOutcome {
  saved,
  duplicateSku,
  invalidName,
  invalidSku,
  invalidCategory,
  invalidUnit,
  invalidCost,
  invalidReorder,
  invalidNotes,
  unitLocked,
  notFound,
  permissionDenied,
  failed,
}
