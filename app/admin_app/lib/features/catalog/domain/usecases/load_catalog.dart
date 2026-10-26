import 'package:admin_app/core/catalog/admin_catalog_snapshot.dart';
import 'package:admin_app/core/catalog/catalog_repository.dart';

/// يقرأ صفحة واحدة؛ القصّ يحدث في القاعدة فلا تطلب اللوحة الكتالوج كله دفعة واحدة.
class LoadCatalogUseCase {
  const LoadCatalogUseCase(this._repository);

  final CatalogRepository _repository;

  Future<AdminCatalogSnapshot> call({
    String? branchId,
    int? limit,
    int offset = 0,
    String? search,
  }) => _repository.loadCatalog(
    branchId: branchId,
    limit: limit,
    offset: offset,
    search: search,
  );
}
