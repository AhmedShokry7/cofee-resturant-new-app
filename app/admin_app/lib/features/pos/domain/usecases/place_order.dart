import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/domain/entities/pos_order_result.dart';

/// إرسال طلب الكاشير إلى القاعدة.
class PlaceOrderUseCase {
  const PlaceOrderUseCase(this._repository);

  final PosRepository _repository;

  Future<PosOrderResult> call({
    required String branchId,
    required List<Map<String, Object?>> lines,
    required String fulfillmentType,
    required String paymentMethodId,
    required String idempotencyKey,
    String? tableId,
    String? note,
    String? customerId,
    List<Map<String, Object?>>? payments,
  }) => _repository.placeOrder(
    branchId: branchId,
    lines: lines,
    fulfillmentType: fulfillmentType,
    paymentMethodId: paymentMethodId,
    idempotencyKey: idempotencyKey,
    tableId: tableId,
    note: note,
    customerId: customerId,
    payments: payments,
  );
}
