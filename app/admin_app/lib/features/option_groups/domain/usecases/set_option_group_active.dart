import 'package:admin_app/features/option_groups/domain/repositories/option_group_repository.dart';

/// تنشيط المجموعة أو إيقافها، وهو البديل الآمن الذي تقبله القاعدة دائمًا.
class SetOptionGroupActiveUseCase {
  const SetOptionGroupActiveUseCase(this._repository);

  final OptionGroupRepository _repository;

  Future<void> call(String groupId, bool isActive) =>
      _repository.setGroupActive(groupId, isActive);
}
