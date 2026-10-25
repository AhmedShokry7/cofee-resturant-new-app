import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

class OrderFilterButtonBar extends StatelessWidget {
  const OrderFilterButtonBar({
    super.key,
    required this.active,
    required this.onToggle,
    required this.onClear,
    this.trailing,
  });

  final bool active;
  final VoidCallback onToggle, onClear;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (trailing != null) Expanded(child: trailing!),
      Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE3E9E4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.ordersFilter,
                  style: const TextStyle(
                    color: Color(0xFF52635A),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(width: 9),
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedFilter,
                  size: 16,
                  color: Color(0xFF52635A),
                ),
              ],
            ),
          ),
        ),
      ),
      if (active) ...[
        const SizedBox(width: AppDimensions.xs),
        IconButton(
          tooltip: S.clearFilters,
          onPressed: onClear,
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedCancel01,
            size: 18,
            color: AppColor.greyColor,
          ),
        ),
      ],
    ],
  );
}
