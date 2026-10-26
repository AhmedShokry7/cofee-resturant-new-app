import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/pos/data/models/pos_order_result.dart';
import 'package:admin_app/features/pos/data/repositories/admin_pos_repository.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_cubit.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_state.dart';

String posAmount(num value) => localizeDigits(formatAmount(value));

double posRoundPrice(double value) => (value * 100).roundToDouble() / 100;

String posMoney(num value, String currencyCode) =>
    '${posAmount(value)} $currencyCode';

String posPercent(num value) {
  final fixed = value
      .toDouble()
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'\.?0+$'), '');
  return '${localizeDigits(fixed)}%';
}

String posDateTime(DateTime? value) =>
    value == null ? '-' : localizeDigits(formatDateTime(value));

/// A compact clock such as `14:05`, used where a full date would not fit.
String posClock(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return localizeDigits('$hour:$minute');
}

String posDiscountText(double percentage) =>
    S.posDiscountLabel(localizeDigits('${percentage.round()}'));

/// Formats an amount for a text field: no trailing zeros, localized digits.
String posMoneyInput(double value) {
  if (value <= 0) return '';
  final fixed = value.toStringAsFixed(2);
  final trimmed = fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return localizeDigits(trimmed);
}

/// Parses a money field, accepting Arabic-Indic digits, commas and spaces.
double? posParseAmount(String raw) {
  final normalized = normalizeDigits(raw)
      .replaceAll(',', '')
      .replaceAll(' ', '');
  if (normalized.isEmpty) return null;
  final value = double.tryParse(normalized);
  if (value == null || !value.isFinite || value < 0) return null;
  return value;
}

String posTenderLabel(PosTender tender, AppLanguage language) =>
    switch (tender.code) {
      'cash' => S.posPayCash,
      'card' => S.posPayCard,
      _ => tender.nameFor(language),
    };

String posCheckoutMessage(PosCheckoutOutcome outcome) => switch (outcome) {
  PosCheckoutOutcome.success => S.posOrderSent,
  PosCheckoutOutcome.emptyCart => S.posEmptyCartMessage,
  PosCheckoutOutcome.branchMissing => S.posBranchMissing,
  PosCheckoutOutcome.shiftRequired => S.posShiftRequiredMessage,
  PosCheckoutOutcome.paymentMissing => S.posPaymentRequired,
  PosCheckoutOutcome.paymentInvalid => S.posSplitInvalidMessage,
  PosCheckoutOutcome.tableUnavailable => S.posTableUnavailableCheckout,
  PosCheckoutOutcome.permissionDenied => S.posPermissionDenied,
  PosCheckoutOutcome.stockUnavailable => S.posStockUnavailable,
  PosCheckoutOutcome.productUnavailable => S.posProductUnavailable,
  PosCheckoutOutcome.branchUnavailable => S.posBranchUnavailable,
  PosCheckoutOutcome.paymentUnavailable => S.posPaymentUnavailable,
  PosCheckoutOutcome.customerUnavailable => S.posCustomerUnavailable,
  PosCheckoutOutcome.invalid => S.posInvalidOrder,
  PosCheckoutOutcome.conflict => S.posConflict,
  PosCheckoutOutcome.busy || PosCheckoutOutcome.failed => S.posCheckoutFailed,
};

String posCheckoutBlockerMessage(PosCheckoutBlocker blocker) =>
    switch (blocker) {
      PosCheckoutBlocker.emptyCart => S.posEmptyCartMessage,
      PosCheckoutBlocker.branchMissing => S.posBranchMissing,
      PosCheckoutBlocker.shiftMissing => S.posShiftRequiredMessage,
      PosCheckoutBlocker.paymentMissing => S.posPaymentRequired,
      PosCheckoutBlocker.paymentInvalid => S.posSplitInvalidMessage,
      PosCheckoutBlocker.tableUnavailable => S.posTableUnavailableCheckout,
    };

String posTablesFailureMessage(PosTablesFailure? failure) => switch (failure) {
  PosTablesFailure.permissionDenied => S.posPermissionDenied,
  _ => S.posTablesLoadFailed,
};

String posSeatOutcomeMessage(PosSeatOutcome outcome) => switch (outcome) {
  PosSeatOutcome.success => S.posSeatGuestToast,
  PosSeatOutcome.tooEarly => S.reservationSeatTooEarly,
  PosSeatOutcome.invalidStatus => S.reservationStatusInvalid,
  PosSeatOutcome.tableBusy => S.reservationTableBusy,
  PosSeatOutcome.invalidTable => S.reservationTableUnavailable,
  PosSeatOutcome.notFound => S.reservationNotFound,
  PosSeatOutcome.permissionDenied => S.posPermissionDenied,
  PosSeatOutcome.failed => S.posSeatGuestFailed,
};

String posCustomerSearchFailureMessage(PosCustomerFailure? failure) =>
    switch (failure) {
      PosCustomerFailure.permissionDenied => S.posCustomerPermissionDenied,
      PosCustomerFailure.invalid => S.posCustomerInvalid,
      _ => S.posCustomerLoadFailed,
    };

String posCustomerCreateFailureMessage(PosCustomerFailure? failure) =>
    switch (failure) {
      PosCustomerFailure.permissionDenied => S.posCustomerPermissionDenied,
      PosCustomerFailure.invalid => S.posCustomerInvalid,
      _ => S.posCustomerCreateFailed,
    };

String posShiftFailureMessage(PosShiftFailure? failure) => switch (failure) {
  PosShiftFailure.permissionDenied => S.posShiftPermissionDenied,
  PosShiftFailure.branchUnavailable => S.posBranchUnavailable,
  PosShiftFailure.notFound => S.posShiftNotFound,
  PosShiftFailure.alreadyClosed => S.posShiftAlreadyClosed,
  PosShiftFailure.invalid => S.posShiftInvalid,
  PosShiftFailure.failed || null => S.posShiftFailed,
};
