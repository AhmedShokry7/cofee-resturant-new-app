import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// زرّ رجوع الخيار إلى زيادة المجموعة: يمحو صفّ التجاوز من
/// `catalog.product_option_value_pricing`، فيعود الرقم إلى ما كان عليه قبل 229.
///
/// لا يُعرض حين لا تجاوز ولا كتابة: لا فعل لمن لا شيء له.
class ProductOptionResetButton extends StatelessWidget {
  const ProductOptionResetButton({
    super.key,
    required this.valueId,
    required this.onPressed,
  });

  final String valueId;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: ValueKey('product-option-reset-$valueId'),
      tooltip: S.resetToGroupPrice,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(
          AppDimensions.recordFieldActionWidth,
          AppDimensions.recordFieldActionWidth,
        ),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: AppIcon(
        AppIcons.undo,
        size: 15,
        color: adminMutedColor(Theme.of(context)),
      ),
    );
  }
}
