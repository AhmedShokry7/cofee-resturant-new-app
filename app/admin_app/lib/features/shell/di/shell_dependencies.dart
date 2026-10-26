import 'package:admin_app/features/shell/data/repositories/admin_nav_repository.dart';
import 'package:admin_app/features/shell/domain/repositories/nav_repository.dart';

/// نقطة تركيب اعتمادات فيتشر الهيكل داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class ShellDependencies {
  ShellDependencies._();

  static NavRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static NavRepository get repository => _repository ??= AdminNavRepository();
}
