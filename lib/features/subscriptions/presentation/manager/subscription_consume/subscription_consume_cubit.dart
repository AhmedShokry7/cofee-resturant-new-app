import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/shared/utils/idempotency_key.dart';

part 'subscription_consume_state.dart';

/// Spends cups from a customer's subscription at the counter.
class SubscriptionConsumeCubit extends Cubit<SubscriptionConsumeState> {
  SubscriptionConsumeCubit({required this._repository})
    : super(const SubscriptionConsumeState());

  final SubscriptionRepository _repository;

  /// The deduction the current idempotency key was made for.
  ///
  /// A retry after a network failure repeats the same request, so it must carry
  /// the same key; a changed token, product or quantity is a different
  /// deduction and gets a fresh one.
  String? _intent;
  String? _idempotencyKey;

  Future<void> consume({
    required String token,
    required String branchId,
    required String productId,
    required String quantityText,
  }) async {
    // A quantity that is not a positive whole number must stop here. Reading
    // it as "1" used to deduct a cup the cashier never asked for.
    final quantity = int.tryParse(quantityText.trim());
    if (quantity == null || quantity < 1) {
      emit(state.copyWith(message: S.invalidQuantity));
      return;
    }
    final intent = '$token|$productId|$quantity';
    emit(state.copyWith(isSubmitting: true, clearMessage: true));
    try {
      final remaining = await _repository.consumeQr(
        token: token.trim(),
        branchId: branchId,
        productId: productId.trim(),
        quantity: quantity,
        idempotencyKey: _keyFor(intent),
      );
      _intent = null;
      _idempotencyKey = null;
      if (isClosed) return;
      emit(
        state.copyWith(
          isSubmitting: false,
          message: S.cupsRemaining(remaining),
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(isSubmitting: false, message: S.couldNotDeductCups));
      addError(error, stackTrace);
    }
  }

  String _keyFor(String intent) {
    if (_intent != intent) {
      _intent = intent;
      _idempotencyKey = IdempotencyKey.create();
    }
    return _idempotencyKey!;
  }
}
