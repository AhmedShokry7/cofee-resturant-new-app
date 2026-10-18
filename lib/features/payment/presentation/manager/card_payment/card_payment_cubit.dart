import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/features/payment/data/repositories/tap_payment_repository.dart';

import 'card_payment_state.dart';

class CardPaymentCubit extends Cubit<CardPaymentState> {
  CardPaymentCubit({
    required this.repository,
    required this.sourceTokenProvider,
    required this.chargeId,
  }) : super(const CardPaymentState());

  final TapPaymentRepository repository;
  final Future<String?> Function() sourceTokenProvider;
  final String chargeId;

  void onCardValidInput(bool isValid) {
    if (state.isBusy) return;
    if (isValid) {
      if (state.status != CardPaymentStatus.cardInputValid) {
        emit(state.copyWith(status: CardPaymentStatus.cardInputValid, clearError: true));
      }
    } else {
      if (state.status != CardPaymentStatus.cardInputInvalid) {
        emit(state.copyWith(status: CardPaymentStatus.cardInputInvalid, clearError: true));
      }
    }
  }

  Future<void> createCharge() async {
    if (state.isBusy) return;
    if (state.status != CardPaymentStatus.cardInputValid) {
      emit(state.copyWith(
        status: CardPaymentStatus.cardInputInvalid,
        errorMessage: 'Please enter valid card details',
      ));
      return;
    }

    emit(state.copyWith(status: CardPaymentStatus.tokenizing, clearError: true));

    final token = await sourceTokenProvider();
    if (isClosed) return;

    if (token == null || token.isEmpty) {
      emit(state.copyWith(
        status: CardPaymentStatus.tokenizationFailed,
        errorMessage: 'Tokenization failed. Please try again.',
      ));
      return;
    }

    emit(state.copyWith(status: CardPaymentStatus.creatingCharge));

    try {
      final result = await repository.createCharge(
        orderId: chargeId,
        idempotencyKey: chargeId,
        sourceToken: token,
      );
      if (isClosed) return;

      emit(state.copyWith(
        status: CardPaymentStatus.chargeCreated,
        chargeId: result.chargeId,
        transactionUrl: result.transactionUrl,
      ));
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(
        status: CardPaymentStatus.paymentFailed,
        errorMessage: 'Payment failed. Please try again.',
      ));
    }
  }

  Future<String?> verifyCharge() async {
    final id = state.chargeId;
    if (id == null || id.isEmpty) return null;

    emit(state.copyWith(status: CardPaymentStatus.verifying, clearError: true));

    try {
      final result = await repository.verifyCharge(id);
      if (isClosed) return null;

      if (result.verified) {
        emit(state.copyWith(status: CardPaymentStatus.paymentSucceeded));
        return 'succeeded';
      } else if (result.orderPaymentStatus == 'pending') {
        emit(state.copyWith(status: CardPaymentStatus.paymentPending));
        return 'pending';
      } else {
        emit(state.copyWith(
          status: CardPaymentStatus.paymentFailed,
          errorMessage: 'Payment was not completed.',
        ));
        return 'failed';
      }
    } catch (error) {
      if (isClosed) return null;
      emit(state.copyWith(
        status: CardPaymentStatus.paymentFailed,
        errorMessage: 'Payment verification failed.',
      ));
      return 'failed';
    }
  }

  String extractTokenId(String successResponse) {
    try {
      final map = jsonDecode(successResponse);
      if (map is Map) {
        final id = map['id'];
        if (id is String && id.isNotEmpty) return id;
      }
    } catch (_) {}
    return '';
  }
}
