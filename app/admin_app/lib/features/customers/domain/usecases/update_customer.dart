import 'package:admin_app/features/customers/domain/repositories/customer_repository.dart';

/// تحديث وسوم عميل وملاحظاته الإدارية.
class UpdateCustomerUseCase {
  const UpdateCustomerUseCase(this._repository);

  final CustomerRepository _repository;

  Future<void> call(
    String customerId, {
    bool? isVip,
    bool? isBlacklisted,
    String? adminNotes,
  }) => _repository.updateCustomer(
    customerId,
    isVip: isVip,
    isBlacklisted: isBlacklisted,
    adminNotes: adminNotes,
  );
}
