import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';

enum BtnVariant { primary, secondary, outlined, destructive }

class CustomBtn extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final double? borderRadius;
  final Color? backgroundColor;
  final Color? textColor;
  final BtnVariant variant;
  final bool isLoading;
  final bool enabled;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final LinearGradient? gradient;
  final EdgeInsets? padding;
  final TextStyle? textStyle;
  final String? loadingText;

  /// Brand gradient; [AppColor.primaryColor] is a runtime theming value, so this
  /// cannot be const.
  static final LinearGradient primaryGradient = LinearGradient(
    colors: [AppColor.primaryColor, AppColor.primaryColorEnd],
  );

  const CustomBtn({
    super.key,
    required this.text,
    this.onPressed,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.textColor,
    this.variant = BtnVariant.primary,
    this.isLoading = false,
    this.enabled = true,
    this.leadingIcon,
    this.trailingIcon,
    this.gradient,
    this.padding,
    this.textStyle,
    this.loadingText,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = !enabled || isLoading;
    final effectiveOnPressed = isDisabled ? null : onPressed;

    final Color bgColor;
    final Color fgColor;

    switch (variant) {
      case BtnVariant.primary:
        bgColor = backgroundColor ?? AppColor.primaryColor;
        fgColor = textColor ?? AppColor.whiteColor;
      case BtnVariant.secondary:
        bgColor = backgroundColor ?? AppColor.lightGreyColor;
        fgColor = textColor ?? AppColor.greyColor;
      case BtnVariant.outlined:
        bgColor = backgroundColor ?? Colors.transparent;
        fgColor = textColor ?? AppColor.primaryColor;
      case BtnVariant.destructive:
        bgColor = backgroundColor ?? AppColor.errorColor;
        fgColor = textColor ?? AppColor.whiteColor;
    }

    final effectiveGradient =
        gradient ??
        (variant == BtnVariant.primary && backgroundColor == null
            ? primaryGradient
            : null);
    final radius = borderRadius ?? 14.r;
    final btnHeight = height ?? 52.h;
    final effectivePadding = padding ?? EdgeInsets.symmetric(horizontal: 16.w);

    if (effectiveGradient != null) {
      return SizedBox(
        width: width,
        height: btnHeight,
        child: GestureDetector(
          onTap: effectiveOnPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isDisabled ? null : effectiveGradient,
              color: isDisabled ? bgColor.withValues(alpha: 0.5) : null,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Center(child: _buildContent(context, fgColor)),
          ),
        ),
      );
    }

    Widget btn = SizedBox(
      width: width,
      height: btnHeight,
      child: switch (variant) {
        BtnVariant.outlined => OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDisabled
                ? fgColor.withValues(alpha: 0.5)
                : fgColor,
            side: BorderSide(
              color: isDisabled ? bgColor.withValues(alpha: 0.3) : bgColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
            padding: effectivePadding,
          ),
          onPressed: effectiveOnPressed,
          child: _buildContent(context, fgColor),
        ),
        _ => ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDisabled
                ? bgColor.withValues(alpha: 0.5)
                : bgColor,
            disabledBackgroundColor: bgColor.withValues(alpha: 0.5),
            disabledForegroundColor: fgColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
            padding: effectivePadding,
            elevation: 0,
          ),
          onPressed: effectiveOnPressed,
          child: _buildContent(context, fgColor),
        ),
      },
    );

    return btn;
  }

  Widget _buildContent(BuildContext context, Color fgColor) {
    final ts =
        textStyle ?? AppFonts.semiBold16(context).copyWith(color: fgColor);

    if (isLoading) {
      if (loadingText != null) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: fgColor,
              ),
            ),
            SizedBox(width: 10.w),
            Text(loadingText!, style: ts),
          ],
        );
      }
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColor.whiteColor,
        ),
        // CustomLoadingWidget()
      );
    }

    final hasLeading = leadingIcon != null;
    final hasTrailing = trailingIcon != null;

    if (!hasLeading && !hasTrailing) {
      return Text(text, style: ts);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasLeading) ...[leadingIcon!, SizedBox(width: 8.w)],
        Flexible(
          child: Text(text, style: ts, textAlign: TextAlign.center),
        ),
        if (hasTrailing) ...[SizedBox(width: 8.w), trailingIcon!],
      ],
    );
  }
}
