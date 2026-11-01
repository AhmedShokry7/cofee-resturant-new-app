import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Promo-code entry with an "apply" button and a clear button.
///
/// Owns nothing but its own text state: the controller is handed in so the
/// cart can read the code when applying, and [onChanged] lets the caller clear
/// it after a successful apply.
///
/// The clear button appears only while there is something to clear, so the
/// field looks the same as every other input in the app until the customer
/// actually types.
class PromoCodeField extends StatefulWidget {
  const PromoCodeField({
    super.key,
    required this.controller,
    required this.onApply,
    this.onClear,
    this.error,
  });

  final TextEditingController controller;

  /// Runs the apply action. The keyboard's done key triggers it too.
  final VoidCallback onApply;

  /// Runs when the clear button is pressed. Defaults to just emptying the
  /// field.
  final VoidCallback? onClear;

  /// Why the last attempt was refused, already in the app's language.
  ///
  /// Rendered inline rather than only in a snackbar: a reason the customer has
  /// to dismiss before they can read it twice is not a reason. It persists
  /// until the next attempt so it survives a rebuild.
  final String? error;

  @override
  State<PromoCodeField> createState() => _PromoCodeFieldState();
}

class _PromoCodeFieldState extends State<PromoCodeField> {
  @override
  void initState() {
    super.initState();
    // Typing is the only thing that changes whether the clear button belongs on
    // screen, and `onChanged` alone would not schedule a build for it.
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => widget.onApply(),
                style: AppFonts.regular14(context),
                decoration: InputDecoration(
                  hintText: S.promoCode,
                  hintStyle: AppFonts.regular14(context)
                      .copyWith(color: AppColor.greyColor),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  suffixIcon: widget.controller.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _clear,
                          tooltip: S.clearPromoCode,
                          icon: Icon(
                            AppIcons.close,
                            size: AppSizes.px18,
                            color: AppColor.greyColor,
                          ),
                        ),
                  suffixIconConstraints: BoxConstraints(
                    minWidth: AppSizes.px40,
                    minHeight: AppSizes.px40,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide(
                      color: widget.error == null
                          ? AppColor.borderColor
                          : AppColor.errorColor,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide(
                      color: widget.error == null
                          ? AppColor.primaryColor
                          : AppColor.errorColor,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: widget.onApply,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColor.primaryColor,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  S.apply,
                  style: AppFonts.medium14(context)
                      .copyWith(color: AppColor.whiteColor),
                ),
              ),
            ),
          ],
        ),
        if (widget.error != null) ...[
          SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                AppIcons.alert,
                size: AppSizes.px14,
                color: AppColor.errorColor,
              ),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  widget.error!,
                  style: AppFonts.regular12(context)
                      .copyWith(color: AppColor.errorColor),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
