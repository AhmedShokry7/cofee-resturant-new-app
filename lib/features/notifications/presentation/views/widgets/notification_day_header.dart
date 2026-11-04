import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The line that says which day the rows under it were delivered.
class NotificationDayHeader extends StatelessWidget {
  const NotificationDayHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('notification-day-header'),
      padding: EdgeInsetsDirectional.only(
        start: AppSpacing.xs,
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        label,
        style: AppFonts.medium14(context).copyWith(color: AppColor.greyColor),
      ),
    );
  }
}

/// The calendar day a row belongs to, as midnight of that local day.
///
/// [DateTime.difference] counts 24-hour spans, so a message sent late evening
/// would otherwise land in "yesterday" a few hours later. Comparing the date
/// parts is what the customer reads on the screen.
///
/// A row with no time is not silently pushed into the current day: null keeps
/// it out of every block, and the list draws it without a heading.
DateTime? deliveryDayOf(NotificationModel item) {
  final at = item.createdAt;
  if (at == null) return null;
  final local = at.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// The words one of those days is given in the list.
///
/// Only the two days a customer reads as relative get words. Older ones are
/// written numerically rather than spelled out, because the app keeps no month
/// names of its own and the date is short enough to read in either language.
String notificationDayLabel(DateTime day, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  if (day == today) return S.notificationDayToday;
  if (day == today.subtract(const Duration(days: 1))) {
    return S.notificationDayYesterday;
  }
  final date = '${day.day}/${day.month}';
  return day.year == today.year ? date : '$date/${day.year}';
}
