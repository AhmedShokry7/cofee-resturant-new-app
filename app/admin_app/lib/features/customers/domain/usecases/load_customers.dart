import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/customers/domain/repositories/customer_repository.dart';

/// قراءة كل عملاء اللوحة.
class LoadCustomersUseCase {
  const LoadCustomersUseCase(this._repository);

  final CustomerRepository _repository;

  Future<List<AdminCustomer>> call() => _repository.loadCustomers();
}
