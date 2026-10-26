import 'package:admin_app/features/audit/data/repositories/admin_audit_repository.dart';
import 'package:admin_app/features/audit/domain/repositories/audit_repository.dart';

/// نقطة تركيب اعتمادات فيتشر التدقيق داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class AuditDependencies {
  AuditDependencies._();

  static AuditRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static AuditRepository get repository =>
      _repository ??= AdminAuditRepository();
}
