import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Standard single-button bottom bar: white surface, top border, padding,
/// and one primary [CustomBtn] that stretches full width.
class PrimaryBottomBar extends StatelessWidget {
  const PrimaryBottomBar({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
  });

  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColor.whiteColor,
        border: Border(top: BorderSide(color: AppColor.borderColor)),
      ),
      child: CustomBtn(
        text: text,
        onPressed: onPressed,
        isLoading: isLoading,
        enabled: enabled,
      ),
    );
  }
}
