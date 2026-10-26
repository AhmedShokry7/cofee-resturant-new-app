import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
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
        icon: HugeIcons.strokeRoundedShield01,
        iconBackground: const Color(0xFFE8F3EC),
        iconColor: const Color(0xFF3D8A68),
      ),
      _MetricData(
        label: S.rolesMetricSystem,
        value: rolesCount(system),
        icon: HugeIcons.strokeRoundedSecurityCheck,
        iconBackground: const Color(0xFFE9EDF8),
        iconColor: const Color(0xFF5F70A8),
      ),
      _MetricData(
        label: S.rolesMetricCustom,
        value: rolesCount(roles.length - system),
        icon: HugeIcons.strokeRoundedUserSettings01,
        iconBackground: const Color(0xFFF4EAF5),
        iconColor: const Color(0xFF92679B),
      ),
      _MetricData(
        label: S.rolesMetricPermissions,
        value: rolesCount(distinctPermissions(roles)),
        icon: HugeIcons.strokeRoundedKey01,
        iconBackground: const Color(0xFFFBF2DC),
        iconColor: const Color(0xFFA47B2F),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 900 ? 2 : 4;
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
