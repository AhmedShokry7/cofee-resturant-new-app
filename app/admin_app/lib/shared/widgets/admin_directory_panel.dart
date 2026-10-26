import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// The bordered surface that holds an admin directory list.
class AdminDirectoryPanel extends StatelessWidget {
  const AdminDirectoryPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.md),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: adminCardBorderColor(theme)),
        borderRadius: BorderRadius.circular(15),
        boxShadow: dark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x0A1B362B),
                  blurRadius: 24,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      padding: padding,
      child: child,
    );
  }
}
