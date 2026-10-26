import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';

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
  final void Function(String)? onFieldSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final double? padding;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

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
    this.onFieldSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.padding,
    this.inputFormatters,
    this.maxLines = 1,
    this.bottomPadding = 16,
  });

  @override
  State<CustomTextFormField> createState() => _CustomTextFormFieldState();
}

class _CustomTextFormFieldState extends State<CustomTextFormField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;

    // Light mode focuses with the primary accent; the dark appearance keeps
    // the brand secondary tone so the ring stays visible on dark surfaces.
    final focusColor = theme.brightness == Brightness.dark
        ? colorScheme.secondary
        : colorScheme.primary;

    final borderColor = _isFocused
        ? focusColor
        : onSurface.withValues(alpha: 0.24);

    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null) ...[
            Padding(
              padding: EdgeInsets.only(
                bottom: AppDimensions.fieldLabelBottom,
                left: AppDimensions.fieldLabelGap,
                right: AppDimensions.fieldLabelGap,
              ),
              child: Text(
                widget.label!,
                style: AppFonts.semiBold14(context).copyWith(color: onSurface),
              ),
            ),
          ],
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppDimensions.fieldRadius),
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
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                inputFormatters: widget.inputFormatters,
                maxLines: widget.maxLines,
                autovalidateMode: widget.autovalidateMode,
                validator: widget.validator,
                onSaved: widget.onSaved,
                onChanged: widget.onChanged,
                onFieldSubmitted: widget.onFieldSubmitted,
                cursorColor: focusColor,
                textAlignVertical: TextAlignVertical.center,
                style: AppFonts.semiBold16(context).copyWith(color: onSurface),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: AppFonts.semiBold14(context)
                      .copyWith(color: onSurface.withValues(alpha: 0.55)),
                  prefixIcon: widget.prefixIcon == null
                      ? null
                      : Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: AppDimensions.fieldIconStart,
                            end: AppDimensions.fieldIconEnd,
                          ),
                          child: IconTheme(
                            data: IconThemeData(
                              color: _isFocused
                                  ? focusColor
                                  : onSurface.withValues(alpha: 0.6),
                              size: AppDimensions.fieldIconSize,
                            ),
                            child: widget.prefixIcon!,
                          ),
                        ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: AppDimensions.fieldIconBox,
                    minHeight: AppDimensions.fieldIconMinHeight,
                  ),
                  suffixIcon: widget.suffixIcon,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: AppDimensions.fieldIconBox,
                    minHeight: AppDimensions.fieldIconMinHeight,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppDimensions.fieldPadding,
                    vertical:
                        widget.padding ?? AppDimensions.fieldVerticalPadding,
                  ),
                  filled: false,
                  isDense: false,
                  border: _buildBorder(),
                  enabledBorder: _buildBorder(color: borderColor),
                  focusedBorder: _buildBorder(
                    color: focusColor,
                    width: AppDimensions.fieldFocusBorderWidth,
                  ),
                  errorBorder: _buildBorder(color: colorScheme.error),
                  focusedErrorBorder: _buildBorder(
                    color: colorScheme.error,
                    width: AppDimensions.fieldFocusBorderWidth,
                  ),
                  errorStyle: AppFonts.semiBold12(context)
                      .copyWith(color: colorScheme.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _buildBorder({
    double width = AppDimensions.fieldBorderWidth,
    Color? color,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.fieldRadius),
      borderSide: BorderSide(
        width: width,
        color: color ?? onSurfaceValue.withValues(alpha: 0.24),
      ),
    );
  }

  Color get onSurfaceValue => Theme.of(context).colorScheme.onSurface;
}
