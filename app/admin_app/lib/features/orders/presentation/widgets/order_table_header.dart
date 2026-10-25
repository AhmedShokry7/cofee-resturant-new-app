import 'package:flutter/material.dart';
import 'package:admin_app/core/locale/app_strings.dart';

class OrderTableHeader extends StatelessWidget {
  const OrderTableHeader({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAF8),
      border: Border.all(color: const Color(0xFFEFF2EF)),
    ),
    child: Row(
      children: [
        _cell(S.orderNumber, 2),
        _cell(S.customer, 3),
        _cell(S.date, 2),
        _cell(S.ordersItems, 3),
        _cell(S.total, 2),
        _cell(S.ordersStatus, 2),
      ],
    ),
  );

  Widget _cell(String label, int flex) => Expanded(
    flex: flex,
    child: Text(
      label,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF819087),
        fontSize: 10,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
    ),
  );
}
