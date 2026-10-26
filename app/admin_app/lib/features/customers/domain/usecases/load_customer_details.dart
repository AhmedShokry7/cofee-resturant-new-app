import 'package:admin_app/features/customers/domain/repositories/customer_repository.dart';

/// قراءة تفاصيل عميل واحد.
class LoadCustomerDetailsUseCase {
  const LoadCustomerDetailsUseCase(this._repository);

  final CustomerRepository _repository;

  Future<Map<String, dynamic>> call(String customerId) =>
      _repository.loadCustomerDetails(customerId);
}
