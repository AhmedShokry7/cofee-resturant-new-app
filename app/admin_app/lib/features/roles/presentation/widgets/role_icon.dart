import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/roles/data/models/admin_role.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_format.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// The small tile that marks a role as a system or a custom one.
class RoleIcon extends StatelessWidget {
  const RoleIcon({super.key, required this.role, this.size = 30});

  final AdminRole role;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = roleTypeColor(role);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          color,
          Color.lerp(color, AppColor.whiteColor, .86)!,
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: HugeIcon(
        icon: role.isSystem
            ? HugeIcons.strokeRoundedShield01
            : HugeIcons.strokeRoundedKey01,
        size: size * 0.53,
        color: adminFlagForeground(theme, color),
      ),
    );
  }
}
