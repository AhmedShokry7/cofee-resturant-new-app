import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/motion_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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

  /// Read at build time so published brand changes repaint primary buttons.
  static LinearGradient get primaryGradient => LinearGradient(
    colors: [
      AppColor.primaryColor,
      Color.lerp(AppColor.primaryColor, AppColor.whiteColor, 0.18)!,
    ],
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
        bgColor = backgroundColor ?? AppColor.transparent;
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
    final radius = borderRadius ?? AppRadius.r14;
    final btnHeight = height ?? AppDimensions.buttonHeight;
    final effectivePadding =
        padding ?? EdgeInsets.symmetric(horizontal: AppSpacing.lg);

    if (effectiveGradient != null) {
      return SizedBox(
        width: width,
        height: btnHeight,
        child: GestureDetector(
          onTap: effectiveOnPressed,
          child: AnimatedContainer(
            duration: MotionTokens.stateChange,
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
            // The outline is the whole point of this variant, so it takes the
            // foreground colour. The background stays transparent, and a border
            // drawn with it would be a button with no border at all.
            side: BorderSide(
              color: isDisabled ? fgColor.withValues(alpha: 0.3) : fgColor,
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
            elevation: AppElevation.flat,
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
              width: AppSizes.px22,
              height: AppSizes.px22,
              child: CircularProgressIndicator(
                strokeWidth: AppSizes.px2_5,
                color: fgColor,
              ),
            ),
            SizedBox(width: AppSizes.px10),
            Text(loadingText!, style: ts),
          ],
        );
      }
      return const SizedBox(
        width: AppSizes.px24,
        height: AppSizes.px24,
        child: CircularProgressIndicator(
          strokeWidth: AppSizes.px2_5,
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
        if (hasLeading) ...[leadingIcon!, SizedBox(width: AppSpacing.sm)],
        Flexible(
          child: Text(text, style: ts, textAlign: TextAlign.center),
        ),
        if (hasTrailing) ...[SizedBox(width: AppSpacing.sm), trailingIcon!],
      ],
    );
  }
}

/// Shared text action for compact actions where a full-width [CustomBtn] would
/// be too heavy. The application theme provides its typography and colors.
class CustomTextButton extends StatelessWidget {
  const CustomTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.onLongPress,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  }) : icon = null,
       label = null;

  const CustomTextButton.icon({
    super.key,
    required this.onPressed,
    required Widget this.icon,
    required Widget this.label,
    this.onLongPress,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  }) : child = null;

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final buttonIcon = icon;
    if (buttonIcon != null) {
      return TextButton.icon(
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: style,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        icon: buttonIcon,
        label: label!,
      );
    }
    return TextButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: child!,
    );
  }
}

/// Shared filled action in compact or tonal forms. Primary actions should use
/// [CustomBtn]; this component covers inline and secondary filled actions.
class CustomFilledButton extends StatelessWidget {
  const CustomFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.onLongPress,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  }) : icon = null,
       label = null,
       isTonal = false;

  const CustomFilledButton.icon({
    super.key,
    required this.onPressed,
    required Widget this.icon,
    required Widget this.label,
    this.onLongPress,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  }) : child = null,
       isTonal = false;

  const CustomFilledButton.tonal({
    super.key,
    required this.onPressed,
    required this.child,
    this.onLongPress,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  }) : icon = null,
       label = null,
       isTonal = true;

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final bool isTonal;

  @override
  Widget build(BuildContext context) {
    if (isTonal) {
      return FilledButton.tonal(
        onPressed: onPressed,
        onLongPress: onLongPress,
        style:
            style ??
            FilledButton.styleFrom(
              backgroundColor: AppColor.lightGreyColor,
              foregroundColor: AppColor.textPrimary,
            ),
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        child: child!,
      );
    }
    final buttonIcon = icon;
    if (buttonIcon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: style,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        icon: buttonIcon,
        label: label!,
      );
    }
    return FilledButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: child!,
    );
  }
}

/// Shared outlined action used for low-emphasis actions across customer pages.
class CustomOutlinedButton extends StatelessWidget {
  const CustomOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.onLongPress,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  }) : icon = null,
       label = null;

  const CustomOutlinedButton.icon({
    super.key,
    required this.onPressed,
    required Widget this.icon,
    required Widget this.label,
    this.onLongPress,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  }) : child = null;

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final buttonIcon = icon;
    if (buttonIcon != null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: style,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        icon: buttonIcon,
        label: label!,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: child!,
    );
  }
}

/// Shared icon-only button with the same sizing and colors as the app theme.
class CustomIconButton extends StatelessWidget {
  const CustomIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.onLongPress,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.isSelected,
    this.selectedIcon,
    this.padding,
    this.constraints,
    this.alignment = Alignment.center,
    this.visualDensity,
    this.iconSize,
    this.color,
  }) : variant = _CustomIconButtonVariant.standard;

  const CustomIconButton.filledTonal({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.style,
    this.focusNode,
    this.autofocus = false,
  }) : onLongPress = null,
       isSelected = null,
       selectedIcon = null,
       padding = null,
       constraints = null,
       alignment = Alignment.center,
       visualDensity = null,
       iconSize = null,
       color = null,
       variant = _CustomIconButtonVariant.filledTonal;

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget icon;
  final Widget? selectedIcon;
  final String? tooltip;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool? isSelected;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final AlignmentGeometry alignment;
  final VisualDensity? visualDensity;
  final double? iconSize;
  final Color? color;
  final _CustomIconButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    if (variant == _CustomIconButtonVariant.filledTonal) {
      return IconButton.filledTonal(
        onPressed: onPressed,
        tooltip: tooltip,
        style: style,
        focusNode: focusNode,
        autofocus: autofocus,
        icon: icon,
      );
    }
    return IconButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      tooltip: tooltip,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      isSelected: isSelected,
      selectedIcon: selectedIcon,
      padding: padding,
      constraints: constraints,
      alignment: alignment,
      visualDensity: visualDensity,
      iconSize: iconSize,
      color: color,
      icon: icon,
    );
  }
}

enum _CustomIconButtonVariant { standard, filledTonal }
