import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/roles/data/models/admin_role.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_format.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

class RoleMetricsCards extends StatelessWidget {
  const RoleMetricsCards({super.key, required this.roles});

  final List<AdminRole> roles;

  @override
  Widget build(BuildContext context) {
    final system = roles.where((role) => role.isSystem).length;
    final cards = <_MetricData>[
      _MetricData(
        label: S.rolesMetricTotal,
        value: rolesCount(roles.length),
        icon: AppIcons.shield01,
        iconBackground: AppColor.tintGreenSurface,
        iconColor: AppColor.trendPositive,
      ),
      _MetricData(
        label: S.rolesMetricSystem,
        value: rolesCount(system),
        icon: AppIcons.securityCheck,
        iconBackground: AppColor.adminInfoSurface,
        iconColor: AppColor.adminInfo,
      ),
      _MetricData(
        label: S.rolesMetricCustom,
        value: rolesCount(roles.length - system),
        icon: AppIcons.userSettings01,
        iconBackground: AppColor.tintMauveSurface,
        iconColor: AppColor.tintMauveInk,
      ),
      _MetricData(
        label: S.rolesMetricPermissions,
        value: rolesCount(distinctPermissions(roles)),
        icon: AppIcons.passwordKey,
        iconBackground: AppColor.adminWarningSurface,
        iconColor: AppColor.adminWarning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < AppBreakpoints.wideLayout ? 2 : 4;
        const spacing = 13.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: AdminMetricCard(
                  label: card.label,
                  value: card.value,
                  icon: card.icon,
                  iconBackground: card.iconBackground,
                  iconColor: card.iconColor,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
}
