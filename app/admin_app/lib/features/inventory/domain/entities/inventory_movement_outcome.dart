/// نتيجة تسجيل حركة مخزون كما تعيدها قاعدة البيانات.
enum InventoryMovementOutcome {
  success,
  materialNotFound,
  invalidBranch,
  invalidType,
  invalidQuantity,
  invalidCost,
  insufficientStock,
  noChange,
  permissionDenied,
  failed,
}
