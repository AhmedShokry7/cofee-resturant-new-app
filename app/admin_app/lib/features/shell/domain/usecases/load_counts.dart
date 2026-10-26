import 'package:admin_app/features/shell/data/models/admin_nav_counts.dart';
import 'package:admin_app/features/shell/domain/repositories/nav_repository.dart';

/// قراءة عدّادات الشريط الجانبي.
class LoadCountsUseCase {
  const LoadCountsUseCase(this._repository);

  final NavRepository _repository;

  Future<AdminNavCounts> call() => _repository.loadCounts();
}
