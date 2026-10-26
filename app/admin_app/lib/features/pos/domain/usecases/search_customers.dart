import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/domain/entities/pos_customer.dart';

/// قراءة العملاء المطابقين لبحث الكاشير.
class SearchCustomersUseCase {
  const SearchCustomersUseCase(this._repository);

  final PosRepository _repository;

  Future<List<PosCustomer>> call({String? query}) =>
      _repository.searchCustomers(query: query);
}
