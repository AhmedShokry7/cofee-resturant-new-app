import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/domain/entities/pos_customer.dart';

/// إنشاء عميل كاشير جديد.
class CreateCustomerUseCase {
  const CreateCustomerUseCase(this._repository);

  final PosRepository _repository;

  Future<PosCustomer> call({
    required String fullName,
    String? phone,
    String? email,
    String? note,
  }) => _repository.createCustomer(
    fullName: fullName,
    phone: phone,
    email: email,
    note: note,
  );
}
