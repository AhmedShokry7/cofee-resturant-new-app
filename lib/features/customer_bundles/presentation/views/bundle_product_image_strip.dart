import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/customer_bundles/data/model/customer_bundle.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

class BundleProductImageStrip extends StatelessWidget {
  const BundleProductImageStrip({
    required this.items,
    this.imageSize = 34,
    this.maxImages = 4,
    this.showMoreCount = true,
    super.key,
  });

  final List<CustomerBundleItem> items;
  final double imageSize;
  final int maxImages;
  final bool showMoreCount;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(maxImages).toList(growable: false);
    if (visible.isEmpty) {
      return Icon(AppIcons.bundle, color: AppColor.greyColor, size: imageSize);
    }
    return SizedBox(
      height: imageSize,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < visible.length; index++) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.r8),
              child: SizedBox.square(
                dimension: imageSize,
                child: visible[index].productImageUrl?.trim().isNotEmpty == true
                    ? DbImage(
                        image: visible[index].productImageUrl,
                        fit: BoxFit.cover,
                        width: imageSize,
                        height: imageSize,
                      )
                    : _placeholder(imageSize),
              ),
            ),
            if (index < visible.length - 1 ||
                (showMoreCount && items.length > visible.length))
              const SizedBox(width: AppSpacing.xs),
          ],
          if (showMoreCount && items.length > visible.length)
            Container(
              width: imageSize,
              height: imageSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColor.greyColor.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
              child: Text(
                '+${items.length - visible.length}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(double size) => Container(
    color: AppColor.greyColor.withValues(alpha: .10),
    alignment: Alignment.center,
    child: Icon(AppIcons.coffee, size: size * .55, color: AppColor.greyColor),
  );
}
