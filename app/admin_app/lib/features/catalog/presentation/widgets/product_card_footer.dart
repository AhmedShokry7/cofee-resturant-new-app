import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

/// The "more" and "product data" row above the save bar.
class ProductCardFooter extends StatelessWidget {
  const ProductCardFooter({
    super.key,
    required this.onMore,
    required this.onProductData,
    this.moreKey,
  });
  final VoidCallback? onMore;
  final VoidCallback? onProductData;

  /// Finds the button of the menu, so the menu opens under it.
  final GlobalKey? moreKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColor.recordBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: moreKey,
              onTap: onMore,
              child: SizedBox(
                height: AppDimensions.recordFooterHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      S.more,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColor.recordText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: AppColor.recordBorder),
                ),
              ),
              child: InkWell(
                onTap: onProductData,
                child: SizedBox(
                  height: AppDimensions.recordFooterHeight,
                  child: Center(
                    child: Text(
                      S.productData,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColor.recordText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The tinted bar that holds the save action.
class ProductCardSaveBar extends StatelessWidget {
  const ProductCardSaveBar({
    super.key,
    required this.onPressed,
    this.isSaving = false,
  });

  final VoidCallback? onPressed;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.primaryColor,
      child: InkWell(
        onTap: isSaving ? null : onPressed,
        child: SizedBox(
          height: AppDimensions.recordSaveBarHeight,
          child: Center(
            child: isSaving
                ? const SizedBox(
                    width: AppDimensions.spinnerSize,
                    height: AppDimensions.spinnerSize,
                    child: CircularProgressIndicator(
                      strokeWidth: AppDimensions.spinnerStroke,
                      color: AppColor.whiteColor,
                    ),
                  )
                : Text(
                    S.save,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColor.whiteColor, fontSize: 14),
                  ),
          ),
        ),
      ),
    );
  }
}
