import 'package:flutter/material.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';

class OrderTableStatusPill extends StatelessWidget {
  const OrderTableStatusPill({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _label => switch (status) {
    'preparing' => S.ordersPreparing,
    'out_for_delivery' => S.orderShipped,
    _ => OrderStatusView.of(status).label,
  };

  Color get _color => switch (status) {
    'out_for_delivery' => const Color(0xFF5180A7),
    'completed' => const Color(0xFF267660),
    'cancelled' => const Color(0xFFB85C5C),
    _ => const Color(0xFFAA7C31),
  };

  Color get _background => switch (status) {
    'out_for_delivery' => const Color(0xFFEDF5FB),
    'completed' => const Color(0xFFE6F1EB),
    'cancelled' => const Color(0xFFFCEEEE),
    _ => const Color(0xFFFFF6DF),
  };
}
