import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';
import 'package:admin_app/features/audit/domain/repositories/audit_repository.dart';

/// قراءة صفحة من سجلات التدقيق مع الفلاتر.
class LoadPageUseCase {
  const LoadPageUseCase(this._repository);

  final AuditRepository _repository;

  Future<AdminAuditPage> call({
    String? search,
    String? domain,
    bool criticalOnly = false,
    int page = 0,
    int pageSize = 20,
  }) => _repository.loadPage(
    search: search,
    domain: domain,
    criticalOnly: criticalOnly,
    page: page,
    pageSize: pageSize,
  );
}
