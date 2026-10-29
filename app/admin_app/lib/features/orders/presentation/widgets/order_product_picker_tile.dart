import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_format.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

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
    subtitle: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            orderMoney(product.basePrice),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSizes.px4),
        const CurrencyIcon(size: 13),
      ],
    ),
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
