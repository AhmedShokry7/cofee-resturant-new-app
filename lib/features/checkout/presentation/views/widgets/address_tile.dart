import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/motion_tokens.dart';
import 'package:new_coffee/features/addresses/data/model/address_model.dart';
import 'package:new_coffee/shared/widgets/selection_radio.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// One saved address: what it says on it, and the actions this screen allows.
///
/// The row itself is the primary tap target and its meaning belongs to the
/// caller - checkout selects the address with it, the address book opens the
/// editor - so the tile never guesses. [onSetDefault], [onEdit] and [onDelete]
/// are drawn only when the caller offers them, and the selection radio only
/// when [showSelector] is true: a screen where a tap means "edit this one"
/// must not show a radio that promises a selection it never makes.
class AddressTile extends StatelessWidget {
  const AddressTile({
    super.key,
    required this.address,
    required this.selected,
    required this.onTap,
    this.onSetDefault,
    this.onEdit,
    this.onDelete,
    this.showSelector = true,
  });

  final AddressModel address;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onSetDefault;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Whether the trailing selection radio is drawn at all.
  final bool showSelector;

  @override
  Widget build(BuildContext context) {
    // Selection paints the card; an edit-only row is a plain surface.
    final isSelected = showSelector && selected;
    return Semantics(
      button: true,
      selected: showSelector ? selected : null,
      // No InkWell wash: its ripple read as a stained rectangle under the
      // card.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: MotionTokens.stateChange,
          margin: EdgeInsets.only(bottom: AppSpacing.sm),
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.r12),
            color: isSelected ? AppColor.primarySoft : AppColor.cardSurface,
            border: Border.all(
              color: isSelected ? AppColor.primaryColor : AppColor.borderColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          // Centered: with the trailing radio middle-aligned on the right,
          // the leading pin reads best on the same midline.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: S.shippingAddress,
                child: Icon(
                  AppIcons.location,
                  size: AppIconSize.lg,
                  color: isSelected
                      ? AppColor.primaryColor
                      : AppColor.greyColor,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            address.label,
                            style: AppFonts.semiBold16(context),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (address.isDefault) ...[
                          SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColor.primarySoft,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                S.defaultAddress,
                                style: AppFonts.medium10(context)
                                    .copyWith(color: AppColor.primaryColorDeep),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      address.details,
                      style: AppFonts.regular14(context)
                          .copyWith(color: AppColor.greyColor),
                    ),
                    if (!address.isDefault && onSetDefault != null)
                      _LinkButton(
                        label: S.setDefaultAddress,
                        onTap: onSetDefault!,
                      ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.md),
              if (onEdit != null)
                IconButton(
                  icon: const Icon(AppIcons.edit, size: AppIconSize.xl),
                  tooltip: S.editAddress,
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(AppIcons.delete, size: AppIconSize.xl),
                  tooltip: S.deleteAddress,
                  onPressed: onDelete,
                ),
              // The radio sits on the right, on the vertical middle of the
              // card, not pinned to its top edge.
              if (showSelector) ...[
                SizedBox(width: AppSpacing.xs),
                SelectionRadio(selected: selected),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A sentence that acts, big enough to hit and named for a screen reader.
class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppDimensions.tapTargetMin,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: Text(
                label,
                style: AppFonts.regular12(context)
                    .copyWith(color: AppColor.primaryColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
