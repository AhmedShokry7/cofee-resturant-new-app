import 'package:flutter/material.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_summary_metric_format.dart';

class OrderTableDateCell extends StatelessWidget {
  const OrderTableDateCell({super.key, required this.value});
  final DateTime? value;

  @override
  Widget build(BuildContext context) {
    final placed = value?.toLocal();
    if (placed == null) return Text('—', style: _style);
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    if (!_sameDay(placed, now) && !_sameDay(placed, yesterday)) {
      return Text(formatDateTime(placed), style: _style);
    }
    final hour = placed.hour % 12 == 0 ? 12 : placed.hour % 12;
    final time =
        '${hour.toString().padLeft(2, '0')}:${placed.minute.toString().padLeft(2, '0')}';
    final suffix = AppLocale.instance.isArabic
        ? placed.hour < 12
              ? 'ص'
              : 'م'
        : placed.hour < 12
        ? 'AM'
        : 'PM';
    final day = _sameDay(placed, now) ? S.ordersToday : S.ordersYesterday;
    return Text(
      OrderSummaryMetricFormat.digits('$day، $time $suffix'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _style,
    );
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  static const _style = TextStyle(
    color: Color(0xFF49584F),
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );
}
