import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/dining_enums.dart';
import 'package:admin_app/core/models/dining_reservation.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/localized_date.dart';

/// Labels, tints and icons of the dining enums, shared by the tables and counter screens.
String diningAreaLabel(DiningArea area) => switch (area) {
  DiningArea.hall => S.tablesAreaHall,
  DiningArea.terrace => S.tablesAreaTerrace,
  DiningArea.privateRoom => S.tablesAreaPrivateRoom,
  DiningArea.other => S.tablesAreaOther,
};

IconData diningAreaIcon(DiningArea area) => switch (area) {
  DiningArea.hall => AppIcons.table01,
  DiningArea.terrace => AppIcons.sun03,
  DiningArea.privateRoom => AppIcons.door01,
  DiningArea.other => AppIcons.sofa01,
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
  DiningTableStatus.available => AppIcons.checkmarkCircle02,
  DiningTableStatus.reserved => AppIcons.calendar01,
  DiningTableStatus.seated => AppIcons.userGroup,
  DiningTableStatus.occupied => AppIcons.restaurant01,
  DiningTableStatus.inactive => AppIcons.cancel01,
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
