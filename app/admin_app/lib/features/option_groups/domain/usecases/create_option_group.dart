import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';
import 'package:admin_app/features/option_groups/domain/repositories/option_group_repository.dart';

/// إنشاء مجموعة أحجام أو إضافات جديدة.
class CreateOptionGroupUseCase {
  const CreateOptionGroupUseCase(this._repository);

  final OptionGroupRepository _repository;

  Future<AdminOptionGroup> call(AdminOptionGroup group) =>
      _repository.createGroup(group);
}
