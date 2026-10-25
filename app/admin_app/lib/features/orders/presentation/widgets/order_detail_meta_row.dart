import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';

class OrderDetailMetaRow extends StatelessWidget {
  const OrderDetailMetaRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColor.greyColor),
          const SizedBox(width: AppDimensions.xs),
          Text('$label: ', style: style?.copyWith(color: AppColor.greyColor)),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: style?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
