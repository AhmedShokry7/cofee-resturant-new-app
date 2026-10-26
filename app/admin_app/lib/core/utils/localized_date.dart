import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/utils/localized_digits.dart';

const _arabicMonths = <String>[
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

const _englishMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A calendar date such as `12 Mar 2024` or `١٢ مارس ٢٠٢٤`.
String localizedDate(DateTime? value) {
  if (value == null) return '—';
  final date = value.toLocal();
  final months = AppLocale.instance.isArabic ? _arabicMonths : _englishMonths;
  return localizeDigits('${date.day} ${months[date.month - 1]} ${date.year}');
}

/// The clock time of [value] with the suffix of the active language.
String localizedTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minutes = local.minute.toString().padLeft(2, '0');
  final arabic = AppLocale.instance.isArabic;
  final suffix = arabic
      ? (local.hour < 12 ? 'ص' : 'م')
      : (local.hour < 12 ? 'AM' : 'PM');
  return localizeDigits('$hour:$minutes $suffix');
}

/// A date and its clock time, separated by a bullet.
String localizedDateTime(DateTime? value) {
  if (value == null) return '—';
  return '${localizedDate(value)} • ${localizedTime(value)}';
}

/// Today or yesterday with the time; any older day falls back to the date.
String localizedRelativeDay(
  DateTime? value, {
  required String todayLabel,
  required String yesterdayLabel,
  String separator = ' • ',
}) {
  if (value == null) return '—';
  final date = value.toLocal();
  final now = DateTime.now();
  final today = _sameDay(date, now);
  final yesterday = _sameDay(date, now.subtract(const Duration(days: 1)));
  if (!today && !yesterday) return localizedDateTime(date);
  final day = today ? todayLabel : yesterdayLabel;
  return '$day$separator${localizedTime(date)}';
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
