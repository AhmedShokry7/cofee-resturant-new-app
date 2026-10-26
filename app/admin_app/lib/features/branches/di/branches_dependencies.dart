import 'package:admin_app/features/branches/data/repositories/admin_branch_repository.dart';
import 'package:admin_app/features/branches/domain/repositories/branch_repository.dart';

/// نقطة تركيب اعتمادات فيتشر الفروع داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class BranchesDependencies {
  BranchesDependencies._();

  static BranchRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static BranchRepository get repository =>
      _repository ??= AdminBranchRepository();
}
