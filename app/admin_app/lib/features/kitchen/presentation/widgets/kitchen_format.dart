import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/fulfillment_type.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_ticket.dart';
import 'package:admin_app/features/kitchen/domain/repositories/kitchen_repository.dart';

/// The age after which an active ticket is flagged for the kitchen.
const int kKitchenLateMinutes = 15;

const List<KitchenTicketStatus> kKitchenBoardStatuses = <KitchenTicketStatus>[
  KitchenTicketStatus.queued,
  KitchenTicketStatus.preparing,
  KitchenTicketStatus.ready,
  KitchenTicketStatus.completed,
];

String kitchenStatusLabel(KitchenTicketStatus status) => switch (status) {
  KitchenTicketStatus.queued => S.kitchenStatusQueued,
  KitchenTicketStatus.preparing => S.statusPreparing,
  KitchenTicketStatus.ready => S.statusReady,
  KitchenTicketStatus.completed => S.kitchenStatusCompleted,
  KitchenTicketStatus.cancelled => S.statusCancelled,
};

String kitchenColumnLabel(KitchenTicketStatus status) => switch (status) {
  KitchenTicketStatus.queued => S.kitchenColumnQueued,
  KitchenTicketStatus.preparing => S.kitchenColumnPreparing,
  KitchenTicketStatus.ready => S.kitchenColumnReady,
  KitchenTicketStatus.completed => S.kitchenColumnCompleted,
  KitchenTicketStatus.cancelled => S.statusCancelled,
};

Color kitchenStatusColor(KitchenTicketStatus status) => switch (status) {
  KitchenTicketStatus.queued => AppColor.adminWarning,
  KitchenTicketStatus.preparing => AppColor.adminInfo,
  KitchenTicketStatus.ready => AppColor.trendPositive,
  KitchenTicketStatus.completed => AppColor.adminMuted,
  KitchenTicketStatus.cancelled => AppColor.trendNegative,
};

IconData kitchenStatusIcon(KitchenTicketStatus status) => switch (status) {
  KitchenTicketStatus.queued => AppIcons.chefHat,
  KitchenTicketStatus.preparing => AppIcons.kitchenUtensils,
  KitchenTicketStatus.ready => AppIcons.checkmarkCircle01,
  KitchenTicketStatus.completed => AppIcons.taskDone01,
  KitchenTicketStatus.cancelled => AppIcons.cancel01,
};

String kitchenItemStatusLabel(KitchenItemStatus status) => switch (status) {
  KitchenItemStatus.pending => S.kitchenItemPending,
  KitchenItemStatus.preparing => S.statusPreparing,
  KitchenItemStatus.ready => S.kitchenItemReady,
};

/// نوع الاستلام على بطاقة المطبخ يُقرأ من نفس تسمية الطلبات.
///
/// كانت البطاقة تملك تبديلًا خاصًا يعتبر أي رمز مجهول «استلامًا من الفرع»، فيخبر
/// المطبخ طلبًا لا يعرف نوعه بأنه سيأتي صاحبه لأخذه. الرمز المجهول الآن صريح.
String kitchenFulfillmentLabel(String type) => fulfillmentLabel(type);

IconData kitchenFulfillmentIcon(String type) => switch (type) {
  'delivery' => AppIcons.deliveryTruck01,
  'dine_in' => AppIcons.restaurantTable,
  _ => AppIcons.shoppingBag01,
};

String kitchenSourceLabel(String source) =>
    source == 'pos' ? S.kitchenSourcePos : S.kitchenSourceOnline;

IconData kitchenSourceIcon(String source) =>
    source == 'pos' ? AppIcons.store01 : AppIcons.globe02;

int kitchenElapsedMinutes(DateTime? placedAt, DateTime now) {
  if (placedAt == null) return 0;
  final minutes = now.toUtc().difference(placedAt.toUtc()).inMinutes;
  return minutes < 0 ? 0 : minutes;
}

bool kitchenIsLate(DateTime? placedAt, DateTime now) =>
    kitchenElapsedMinutes(placedAt, now) >= kKitchenLateMinutes;

String kitchenElapsedLabel(DateTime? placedAt, DateTime now) {
  final minutes = kitchenElapsedMinutes(placedAt, now);
  if (minutes <= 0) return S.kitchenNow;
  if (minutes < 60) {
    return localizeDigits(S.kitchenElapsedMinutes(minutes));
  }
  return localizeDigits(S.kitchenElapsedHours(minutes ~/ 60, minutes % 60));
}

String kitchenHandedOffLabel(DateTime? completedAt) =>
    completedAt == null ? '' : S.kitchenHandedOffAt(localizedTime(completedAt));

String kitchenItemOptions(AdminKitchenTicketItem item) {
  final language = AppLocale.instance.language;
  final options = item.optionsFor(language);
  if (options.isEmpty) return '';
  final primary = language.isArabic
      ? item.optionGroupNameAr
      : item.optionGroupNameEn;
  final fallback = language.isArabic
      ? item.optionGroupNameEn
      : item.optionGroupNameAr;
  final group = primary.trim().isNotEmpty ? primary.trim() : fallback.trim();
  return group.isEmpty ? options : '$group · $options';
}

String kitchenMutationErrorMessage(KitchenMutationOutcome outcome) =>
    switch (outcome) {
      KitchenMutationOutcome.permissionDenied => S.kitchenPermissionDenied,
      KitchenMutationOutcome.notFound => S.kitchenTicketNotFoundMessage,
      KitchenMutationOutcome.invalidStatus ||
      KitchenMutationOutcome.invalidTransition =>
        S.kitchenInvalidTransitionMessage,
      _ => S.kitchenActionFailed,
    };
