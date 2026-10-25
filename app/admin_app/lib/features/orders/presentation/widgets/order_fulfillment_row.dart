import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';

class OrderFulfillmentRow extends StatelessWidget {
  const OrderFulfillmentRow({
    super.key,
    required this.icon,
    required this.label,
    this.muted = false,
  });
  final IconData icon;
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      children: [
        HugeIcon(
          icon: icon,
          size: 14,
          color: muted ? AppColor.greyColor : AppColor.primaryColor,
        ),
        const SizedBox(width: AppDimensions.xs),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: muted ? AppColor.greyColor : null),
          ),
        ),
      ],
    ),
  );
}
