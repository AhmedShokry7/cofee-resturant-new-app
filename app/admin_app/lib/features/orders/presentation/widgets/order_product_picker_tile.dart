import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/formatters.dart';

class OrderProductPickerTile extends StatelessWidget {
  const OrderProductPickerTile({
    super.key,
    required this.product,
    required this.onTap,
  });
  final AdminProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        width: AppSizes.px40,
        height: AppSizes.px40,
        child: product.imageUrl?.isNotEmpty == true
            ? CachedNetworkImage(
                imageUrl: product.imageUrl!,
                fit: BoxFit.fill,
                errorWidget: (_, _, _) => _placeholder(),
              )
            : _placeholder(),
      ),
    ),
    title: Text(
      product.nameFor(AppLocale.instance.language),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(formatMoneyWithCurrency(product.basePrice)),
    onTap: onTap,
  );

  Widget _placeholder() => const ColoredBox(
    color: AppColor.secondaryColor,
    child: AppIcon(
      AppIcons.shoppingBag01,
      size: 20,
      color: AppColor.primaryColor,
    ),
  );
}
