import 'package:admin_app/features/pos/data/repositories/admin_pos_repository.dart';
import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';

/// نقطة تركيب اعتمادات فيتشر نقطة البيع داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class PosDependencies {
  PosDependencies._();

  static PosRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static PosRepository get repository => _repository ??= AdminPosRepository();
}
