import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';
import 'package:admin_app/features/option_groups/domain/repositories/option_group_repository.dart';

/// قراءة كل مجموعات الخيارات مع قيمها ونطاقها.
class LoadOptionGroupsUseCase {
  const LoadOptionGroupsUseCase(this._repository);

  final OptionGroupRepository _repository;

  Future<List<AdminOptionGroup>> call() => _repository.loadGroups();
}
