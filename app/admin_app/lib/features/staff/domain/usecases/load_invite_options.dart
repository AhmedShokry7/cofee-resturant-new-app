import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';

/// الأدوار والفروع التي يملك هذا الموظف أن يضعها في دعوة.
class LoadInviteOptionsUseCase {
  const LoadInviteOptionsUseCase(this._repository);

  final StaffRepository _repository;

  Future<AdminInviteOptions> call() => _repository.loadInviteOptions();
}
