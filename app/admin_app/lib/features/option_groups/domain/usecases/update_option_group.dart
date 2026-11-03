import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';
import 'package:admin_app/features/option_groups/domain/repositories/option_group_repository.dart';

/// تعديل مجموعة قائمة: قيمها وأسعارها ونطاقها.
class UpdateOptionGroupUseCase {
  const UpdateOptionGroupUseCase(this._repository);

  final OptionGroupRepository _repository;

  Future<AdminOptionGroup> call(AdminOptionGroup group) =>
      _repository.updateGroup(group);
}
