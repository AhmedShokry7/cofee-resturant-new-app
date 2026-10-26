import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';

String branchName(AdminBranch branch) =>
    branch.nameFor(AppLocale.instance.language);

String branchCount(int value) => localizeDigits('$value');

String branchOrdersLabel(AdminBranch branch) =>
    localizeDigits(S.branchesOrdersValue(branch.orders30d));

String branchStaffLabel(AdminBranch branch) =>
    localizeDigits(S.branchesStaffValue(branch.staffCount));

String branchZonesLabel(AdminBranch branch) =>
    localizeDigits(S.branchesZonesValue(branch.zoneCount));

/// A database time such as `09:30:00` as `09:30` in the active numerals.
String branchTime(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return '';
  final parts = text.split(':');
  if (parts.length < 2) return localizeDigits(text);
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return localizeDigits(text);
  final clock =
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  return localizeDigits(clock);
}

/// `09:00 – 23:00`, or null when the branch has no opening hours.
String? branchHours(AdminBranch branch) {
  final opens = branchTime(branch.opensAt);
  final closes = branchTime(branch.closesAt);
  if (opens.isEmpty && closes.isEmpty) return null;
  return '$opens – $closes';
}

/// Today or yesterday with the time, or the date for an older order.
String branchLastOrder(AdminBranch branch) {
  final value = branch.lastOrderAt;
  if (value == null) return S.branchesNoOrders;
  return localizedRelativeDay(
    value,
    todayLabel: S.today,
    yesterdayLabel: S.yesterday,
  );
}
