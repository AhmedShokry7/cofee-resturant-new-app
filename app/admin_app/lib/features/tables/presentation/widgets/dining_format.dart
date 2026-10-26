import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/features/tables/data/models/dining_enums.dart';
import 'package:admin_app/features/tables/data/models/dining_reservation.dart';
import 'package:admin_app/features/tables/data/repositories/dining_tables_repository.dart';

String diningAreaLabel(DiningArea area) => switch (area) {
  DiningArea.hall => S.tablesAreaHall,
  DiningArea.terrace => S.tablesAreaTerrace,
  DiningArea.privateRoom => S.tablesAreaPrivateRoom,
  DiningArea.other => S.tablesAreaOther,
};

IconData diningAreaIcon(DiningArea area) => switch (area) {
  DiningArea.hall => HugeIcons.strokeRoundedTable01,
  DiningArea.terrace => HugeIcons.strokeRoundedSun03,
  DiningArea.privateRoom => HugeIcons.strokeRoundedDoor01,
  DiningArea.other => HugeIcons.strokeRoundedSofa01,
};

String diningTableStatusLabel(DiningTableStatus status) => switch (status) {
  DiningTableStatus.available => S.tableStatusAvailable,
  DiningTableStatus.reserved => S.tableStatusReserved,
  DiningTableStatus.seated => S.tableStatusSeated,
  DiningTableStatus.occupied => S.tableStatusOccupied,
  DiningTableStatus.inactive => S.tableStatusInactive,
};

Color diningTableStatusColor(DiningTableStatus status) => switch (status) {
  DiningTableStatus.available => AppColor.trendPositive,
  DiningTableStatus.reserved => AppColor.adminWarning,
  DiningTableStatus.seated => AppColor.adminInfo,
  DiningTableStatus.occupied => AppColor.errorColor,
  DiningTableStatus.inactive => AppColor.adminMuted,
};

Color diningTableStatusSurface(DiningTableStatus status) => switch (status) {
  DiningTableStatus.available => AppColor.trendPositiveSurface,
  DiningTableStatus.reserved => AppColor.adminWarningSurface,
  DiningTableStatus.seated => AppColor.adminInfoSurface,
  DiningTableStatus.occupied => AppColor.errorColor.withValues(alpha: .12),
  DiningTableStatus.inactive => AppColor.adminTableHeader,
};

IconData diningTableStatusIcon(DiningTableStatus status) => switch (status) {
  DiningTableStatus.available => HugeIcons.strokeRoundedCheckmarkCircle02,
  DiningTableStatus.reserved => HugeIcons.strokeRoundedCalendar01,
  DiningTableStatus.seated => HugeIcons.strokeRoundedUserGroup,
  DiningTableStatus.occupied => HugeIcons.strokeRoundedRestaurant01,
  DiningTableStatus.inactive => HugeIcons.strokeRoundedCancel01,
};

String diningReservationStatusLabel(DiningReservationStatus status) =>
    switch (status) {
      DiningReservationStatus.confirmed => S.reservationStatusConfirmed,
      DiningReservationStatus.seated => S.reservationStatusSeated,
      DiningReservationStatus.completed => S.reservationStatusCompleted,
      DiningReservationStatus.cancelled => S.reservationStatusCancelled,
      DiningReservationStatus.noShow => S.reservationStatusNoShow,
    };

Color diningReservationStatusColor(DiningReservationStatus status) =>
    switch (status) {
      DiningReservationStatus.confirmed => AppColor.adminWarning,
      DiningReservationStatus.seated => AppColor.adminAccent,
      DiningReservationStatus.completed => AppColor.trendPositive,
      DiningReservationStatus.cancelled => AppColor.adminMuted,
      DiningReservationStatus.noShow => AppColor.errorColor,
    };

Color diningReservationStatusSurface(DiningReservationStatus status) =>
    switch (status) {
      DiningReservationStatus.confirmed => AppColor.adminWarningSurface,
      DiningReservationStatus.seated => AppColor.adminAccentSurface,
      DiningReservationStatus.completed => AppColor.trendPositiveSurface,
      DiningReservationStatus.cancelled => AppColor.adminTableHeader,
      DiningReservationStatus.noShow => AppColor.errorColor.withValues(
        alpha: .12,
      ),
    };

String diningReservationWhen(DiningReservation reservation) {
  final start = reservation.reservedFor;
  if (start == null) return '—';
  final local = start.toLocal();
  final now = DateTime.now();
  final today = _sameDay(local, now);
  final tomorrow = _sameDay(local, now.add(const Duration(days: 1)));
  if (today) return localizedTime(local);
  if (tomorrow) return '${S.tomorrow} • ${localizedTime(local)}';
  return localizedDateTime(local);
}

String diningReservationWindow(DiningReservation reservation) {
  final start = reservation.reservedFor;
  final end = reservation.endsAt;
  if (start == null || end == null) return diningReservationWhen(reservation);
  final prefix = _sameDay(start.toLocal(), DateTime.now())
      ? ''
      : '${localizedDate(start)} • ';
  return '$prefix${S.reservationTimeRange(localizedTime(start), localizedTime(end))}';
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String diningLoadErrorMessage(String? message) {
  final text = (message ?? '').toLowerCase();
  if (text.contains('permission') || text.contains('42501')) {
    return S.tablesPermissionDenied;
  }
  if (text.contains('no branch') || text.contains('p0002')) {
    return S.tablesNoBranch;
  }
  return S.tablesLoadFailed;
}

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
  DiningReservationSaveOutcome.invalidParty ||
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
  DiningReservationStatusOutcome.notFound => S.reservationNotFound,
  DiningReservationStatusOutcome.permissionDenied => S.tablePermissionDenied,
  DiningReservationStatusOutcome.failed => S.reservationActionFailed,
};
