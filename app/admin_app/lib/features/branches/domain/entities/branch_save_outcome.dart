/// نتيجة حفظ فرع كما تعيدها قاعدة البيانات.
enum BranchSaveOutcome {
  saved,
  duplicateCode,
  invalidCode,
  invalidName,
  invalidAddress,
  invalidHours,
  invalidLocation,
  invalidVatNumber,
  invalidLegalName,
  noBrand,
  notFound,
  permissionDenied,
  failed,
}
