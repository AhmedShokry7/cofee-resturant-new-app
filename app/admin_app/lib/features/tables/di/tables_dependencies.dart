import 'package:admin_app/features/tables/data/repositories/dining_tables_repository.dart';
import 'package:admin_app/features/tables/domain/repositories/dining_table_repository.dart';

/// نقطة تركيب اعتمادات فيتشر طاولات الصالة داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class TablesDependencies {
  TablesDependencies._();

  static DiningTableRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static DiningTableRepository get repository =>
      _repository ??= DiningTablesRepository();
}
