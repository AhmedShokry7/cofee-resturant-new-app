import 'package:admin_app/features/option_groups/domain/repositories/option_group_repository.dart';

/// حذف مجموعة، وترفضها القاعدة إن كانت قيمها بيعت من قبل.
class DeleteOptionGroupUseCase {
  const DeleteOptionGroupUseCase(this._repository);

  final OptionGroupRepository _repository;

  Future<void> call(String groupId) => _repository.deleteGroup(groupId);
}
