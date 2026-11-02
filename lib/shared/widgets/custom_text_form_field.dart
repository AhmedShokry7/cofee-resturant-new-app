import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/motion_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class CustomTextFormField extends StatefulWidget {
  final String hint;
  final String? label;
  final TextEditingController? controller;

  /// Supplied when something outside the field has to react to focus, e.g. to
  /// show a suggestion list while typing.
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final void Function(String?)? onSaved;
  final AutovalidateMode? autovalidateMode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onChanged;

  /// The one glyph that says what the field holds.
  ///
  /// The field, not the screen, picks its size, its colour and how far it sits
  /// from the text, so an address box on the sign-in page and one on the
  /// address page are the same box. Use [prefixIcon] only when the leading
  /// thing is not a glyph - a search pill, for instance.
  ///
  /// Screens pass `icon: AppIcons.mail`; they never pass `Icon(...)` with their
  /// own size or their own grey.
  final IconData? icon;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final double? padding;
  final List<TextInputFormatter>? inputFormatters;

  /// Space below the field. Defaults to 16 (set 8 for denser forms).
  final double bottomPadding;

  const CustomTextFormField({
    super.key,
    required this.hint,
    this.label,
    this.controller,
    this.focusNode,
    this.validator,
    this.onSaved,
    this.autovalidateMode,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.icon,
    this.prefixIcon,
    this.suffixIcon,
    this.padding,
    this.inputFormatters,
    this.bottomPadding = 16,
  });

  @override
  State<CustomTextFormField> createState() => _CustomTextFormFieldState();
}

class _CustomTextFormFieldState extends State<CustomTextFormField> {
  static const double _fieldRadius = AppDimensions.fieldRadius;

  late bool _isObscure;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isObscure = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant CustomTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.obscureText != widget.obscureText) {
      _isObscure = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _isFocused
        ? AppColor.secondryColor
        : AppColor.greyColor.withValues(alpha: 0.35);

    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null) ...[
            Padding(
              padding: EdgeInsets.only(
                bottom: AppSpacing.sm,
                left: AppSpacing.xs,
                right: AppSpacing.xs,
              ),
              child: Text(
                widget.label!,
                style: AppFonts.semiBold14(context)
                    .copyWith(color: AppColor.secondryColor),
              ),
            ),
          ],
          AnimatedContainer(
            duration: MotionTokens.stateChange,
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _isFocused
                  ? AppColor.secondryColor.withValues(
                      alpha: AppShadows.focusTint,
                    )
                  : AppColor.whiteColor,
              borderRadius: BorderRadius.circular(_fieldRadius),
              boxShadow: _isFocused
                  ? AppShadows.focused(AppColor.secondryColor)
                  : const [],
            ),
            child: Focus(
              onFocusChange: (focused) {
                if (_isFocused != focused) {
                  setState(() => _isFocused = focused);
                }
              },
              child: TextFormField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                obscureText: _isObscure,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                inputFormatters: widget.inputFormatters,
                autovalidateMode: widget.autovalidateMode,
                validator: widget.validator,
                onSaved: widget.onSaved,
                onChanged: widget.onChanged,
                cursorColor: AppColor.secondryColor,
                style: AppFonts.semiBold16(context)
                    .copyWith(color: AppColor.secondryColor),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: AppFonts.semiBold14(
                    context,
                  ).copyWith(color: AppColor.greyColor.withValues(alpha: 0.85)),
                  prefixIcon: _buildPrefixIcon(),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: AppSpacing.xxxl,
                    minHeight: AppSpacing.xxxl,
                  ),
                  suffixIcon: _buildSuffixIcon(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSizes.px18,
                    vertical: widget.padding ?? AppSpacing.lg,
                  ),
                  filled: true,
                  fillColor: AppColor.transparent,
                  isDense: false,
                  border: _buildBorder(),
                  enabledBorder: _buildBorder(color: borderColor),
                  focusedBorder: _buildBorder(
                    color: AppColor.secondryColor,
                    width: AppDimensions.fieldBorderWidthActive,
                  ),
                  errorBorder: _buildBorder(color: AppColor.errorColor),
                  focusedErrorBorder: _buildBorder(
                    color: AppColor.errorColor,
                    width: AppDimensions.fieldBorderWidthActive,
                  ),
                  errorStyle: AppFonts.semiBold12(context)
                      .copyWith(color: AppColor.errorColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The leading glyph, or whatever exotic leading widget the screen brought.
  ///
  /// One `IconTheme` covers both, so a screen handing in `Icon(AppIcons.mail)`
  /// cannot accidentally set its own size or its own grey.
  Widget? _buildPrefixIcon() {
    final leading = widget.icon == null ? widget.prefixIcon : Icon(widget.icon);
    if (leading == null) return null;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: AppSizes.px14,
        end: AppSizes.px10,
      ),
      child: IconTheme(
        data: IconThemeData(
          color: _isFocused ? AppColor.secondryColor : AppColor.greyColor,
          size: AppIconSize.field,
        ),
        child: leading,
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.obscureText) {
      return IconButton(
        tooltip: _isObscure ? S.showPassword : S.hidePassword,
        onPressed: () {
          setState(() => _isObscure = !_isObscure);
        },
        icon: Icon(
          _isObscure ? AppIcons.viewOff : AppIcons.view,
          size: AppIconSize.field,
          color: AppColor.greyColor,
        ),
      );
    }

    return widget.suffixIcon;
  }

  OutlineInputBorder _buildBorder({
    double width = AppDimensions.fieldBorderWidth,
    Color? color,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(_fieldRadius),
      borderSide: BorderSide(
        width: width,
        color: color ?? AppColor.greyColor.withValues(alpha: 0.35),
      ),
    );
  }
}
