import 'package:admin_app/features/customers/data/repositories/admin_customer_repository.dart';
import 'package:admin_app/features/customers/domain/repositories/customer_repository.dart';

/// نقطة تركيب اعتمادات فيتشر العملاء داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class CustomersDependencies {
  CustomersDependencies._();

  static CustomerRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static CustomerRepository get repository =>
      _repository ??= AdminCustomerRepository();
}
