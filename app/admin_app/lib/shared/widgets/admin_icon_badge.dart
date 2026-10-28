import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// مربّع أيقونة ملوّن على حافة بطاقة أو داخل شريط.
///
/// العلامة تُقال بلون خفيف وحرف واحد لا بجملة: البطاقة التي تشرح نفسها بعنوانها
/// لا تحتاج أيقونة تزاحم عنوانها، فتُترك الأيقونة علامة بصرية فقط. والوجهان
/// الفاتح والداكن يعرفهما `adminFlag*` وحده، فلا تُحسب شفافية في كل صفحة.
class AdminIconBadge extends StatelessWidget {
  const AdminIconBadge({
    super.key,
    required this.icon,
    this.color,
    this.surface,
    this.size = AppSizes.px34,
    this.iconSize = AppSizes.px20,
  });

  final IconData icon;

  /// لون الحرف، والافتراضي أخضر الإدارة.
  final Color? color;

  /// خلفية المربّع، والافتراضي فتحته اللونية في الثيم الحالي.
  final Color? surface;

  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = color ?? AppColor.adminAccent;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            surface ??
            adminFlagBackground(theme, ink, AppColor.adminAccentSurface),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: AppIcon(
        icon,
        size: iconSize,
        color: adminFlagForeground(theme, ink),
      ),
    );
  }
}
