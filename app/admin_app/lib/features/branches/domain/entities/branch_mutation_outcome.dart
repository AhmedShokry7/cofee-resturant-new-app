/// نتيجة فعلٍ على فرع (تعطيل أو حذف أو صورة) كما تعيده قاعدة البيانات.
enum BranchMutationOutcome {
  success,
  notFound,
  hasOrders,
  hasUsage,
  hasStaff,
  lastActive,
  inUse,
  invalidUrl,
  permissionDenied,
  failed,
}
