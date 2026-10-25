import 'package:flutter/material.dart';

class OrderStatusTab extends StatelessWidget {
  const OrderStatusTab({
    super.key,
    required this.code,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String code, label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  static const _active = Color(0xFF267660);
  static const _inactive = Color(0xFF718078);

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF3EE) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFD5E8DD),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: _active,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? _active : _inactive,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
