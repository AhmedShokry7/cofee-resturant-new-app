import 'package:flutter/material.dart';

import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class OrderFulfillmentRow extends StatelessWidget {
  const OrderFulfillmentRow({
    super.key,
    required this.icon,
    required this.label,
    this.muted = false,
    this.strong = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool muted, strong;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminIconTile(
            icon: icon,
            tint: muted ? AppColor.adminMuted : AppColor.adminAccent,
            surface: muted
                ? adminTintedSurfaceColor(theme)
                : AppColor.adminAccentSurface,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                label,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: muted ? adminMutedColor(theme) : adminBodyColor(theme),
                  fontSize: AppFontSizes.size11,
                  fontWeight: strong
                      ? AppFontWeights.semiBold
                      : AppFontWeights.regular,
                  height: AppTextHeights.line1_6,
                ),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Padding(padding: const EdgeInsets.only(top: 2), child: trailing),
          ],
        ],
      ),
    );
  }
}
