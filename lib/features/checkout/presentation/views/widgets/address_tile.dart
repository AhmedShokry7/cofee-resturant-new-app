import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/addresses/data/model/address_model.dart';
import 'package:new_coffee/shared/widgets/selection_radio.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// One saved address: what it says on it, and the actions this screen allows.
///
/// The row itself is the primary tap target and its meaning belongs to the
/// caller - checkout selects the address with it, the address book opens the
/// editor - so the tile never guesses. [onSetDefault], [onEdit] and [onDelete]
/// are drawn only when the caller offers them.
class AddressTile extends StatelessWidget {
  const AddressTile({
    super.key,
    required this.address,
    required this.selected,
    required this.onTap,
    this.onSetDefault,
    this.onEdit,
    this.onDelete,
  });

  final AddressModel address;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onSetDefault;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                // The glyph keeps its own height but the box around it reaches
                // the accessibility floor, so a tap aimed at the pin lands.
                padding: EdgeInsets.only(top: AppSpacing.xxs),
                child: Semantics(
                  label: S.shippingAddress,
                  child: Icon(
                    AppIcons.location,
                    size: AppIconSize.lg,
                    color: selected
                        ? AppColor.primaryColor
                        : AppColor.greyColor,
                  ),
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
                          SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              S.defaultAddress,
                              style: AppFonts.regular12(context)
                                  .copyWith(color: AppColor.primaryColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
              SelectionRadio(selected: selected),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
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
      ),
    );
  }
}
