import 'package:admin_app/features/customer_preview/data/repositories/supabase_customer_preview_repository.dart';
import 'package:admin_app/features/customer_preview/domain/repositories/customer_preview_repository.dart';

/// نقطة تركيب اعتمادات فيتشر المعاينة داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class CustomerPreviewDependencies {
  CustomerPreviewDependencies._();

  static CustomerPreviewRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static CustomerPreviewRepository get repository =>
      _repository ??= SupabaseCustomerPreviewRepository();
}
