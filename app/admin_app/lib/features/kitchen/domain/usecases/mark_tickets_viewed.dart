import 'package:admin_app/features/kitchen/domain/repositories/kitchen_repository.dart';

/// وسم تيكيتات المطبخ التي عرضتها السبورة بعد فحص صلاحيات الموظف في القاعدة.
class MarkTicketsViewedUseCase {
  const MarkTicketsViewedUseCase(this._repository);

  final KitchenRepository _repository;

  Future<void> call(List<String> ticketIds) =>
      _repository.markTicketsViewed(ticketIds);
}
