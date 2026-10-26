import 'package:flutter/material.dart';

import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// A small muted label above a value, used by the directory cards.
class AdminLabeledValue extends StatelessWidget {
  const AdminLabeledValue({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: adminMutedColor(Theme.of(context)),
            fontSize: AppFontSizes.size9,
            height: AppTextHeights.line1_5,
          ),
        ),
        child,
      ],
    );
  }
}
