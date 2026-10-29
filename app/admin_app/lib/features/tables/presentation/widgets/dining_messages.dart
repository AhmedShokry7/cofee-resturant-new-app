import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/tables/domain/repositories/dining_table_repository.dart';

/// Error copy of a tables action, mapped from the repository outcome.
String diningLoadErrorMessage(DiningLoadFailure? failure) => switch (failure) {
  DiningLoadFailure.permissionDenied => S.tablesPermissionDenied,
  DiningLoadFailure.noBranch => S.tablesNoBranch,
  DiningLoadFailure.failed || null => S.tablesLoadFailed,
};

String diningTableSaveErrorMessage(DiningTableSaveOutcome outcome) =>
    switch (outcome) {
      DiningTableSaveOutcome.saved => '',
      DiningTableSaveOutcome.invalidName ||
      DiningTableSaveOutcome.invalidArea ||
      DiningTableSaveOutcome.invalidCapacity ||
      DiningTableSaveOutcome.invalidNote ||
      DiningTableSaveOutcome.invalidBranch => S.tableSaveFailed,
      DiningTableSaveOutcome.duplicateName => S.tableDuplicateName,
      DiningTableSaveOutcome.notFound => S.tableNotFoundMessage,
      DiningTableSaveOutcome.permissionDenied => S.tablePermissionDenied,
      DiningTableSaveOutcome.failed => S.tableSaveFailed,
    };

String diningTableMutationErrorMessage(DiningTableMutationOutcome outcome) =>
    switch (outcome) {
      DiningTableMutationOutcome.success => '',
      DiningTableMutationOutcome.notFound => S.tableNotFoundMessage,
      DiningTableMutationOutcome.inUse => S.tableInUseMessage,
      DiningTableMutationOutcome.hasHistory => S.tableHasHistoryMessage,
      DiningTableMutationOutcome.permissionDenied => S.tablePermissionDenied,
      DiningTableMutationOutcome.failed => S.tableMutationFailed,
    };

String diningReservationSaveErrorMessage(
  DiningReservationSaveOutcome outcome,
) => switch (outcome) {
  DiningReservationSaveOutcome.saved => '',
  DiningReservationSaveOutcome.invalidName => S.reservationGuestNameRequired,
  DiningReservationSaveOutcome.invalidPhone ||
  DiningReservationSaveOutcome.invalidNote ||
  DiningReservationSaveOutcome.invalidDuration => S.reservationSaveFailed,
  DiningReservationSaveOutcome.invalidParty => S.reservationInvalidParty,
  DiningReservationSaveOutcome.invalidTime => S.reservationInvalidTime,
  DiningReservationSaveOutcome.invalidTable => S.reservationTableUnavailable,
  DiningReservationSaveOutcome.partyTooLarge => S.reservationPartyTooLarge,
  DiningReservationSaveOutcome.overlap => S.reservationOverlap,
  DiningReservationSaveOutcome.closedReservation => S.reservationClosed,
  DiningReservationSaveOutcome.seatedTableLocked =>
    S.reservationSeatedTableLocked,
  DiningReservationSaveOutcome.notFound => S.reservationNotFound,
  DiningReservationSaveOutcome.permissionDenied => S.tablePermissionDenied,
  DiningReservationSaveOutcome.failed => S.reservationSaveFailed,
};

String diningReservationStatusErrorMessage(
  DiningReservationStatusOutcome outcome,
) => switch (outcome) {
  DiningReservationStatusOutcome.success => '',
  DiningReservationStatusOutcome.invalidStatus ||
  DiningReservationStatusOutcome.invalidTable => S.reservationStatusInvalid,
  DiningReservationStatusOutcome.tableBusy => S.reservationTableBusy,
  DiningReservationStatusOutcome.tooEarly => S.reservationSeatTooEarly,
  DiningReservationStatusOutcome.notFound => S.reservationNotFound,
  DiningReservationStatusOutcome.permissionDenied => S.tablePermissionDenied,
  DiningReservationStatusOutcome.failed => S.reservationActionFailed,
};
