import 'package:admin_app/features/payments/data/repositories/admin_payment_repository.dart';
import 'package:admin_app/features/payments/domain/repositories/payment_repository.dart';

/// نقطة تركيب اعتمادات فيتشر المدفوعات داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class PaymentsDependencies {
  PaymentsDependencies._();

  static PaymentRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static PaymentRepository get repository =>
      _repository ??= AdminPaymentRepository();
}
