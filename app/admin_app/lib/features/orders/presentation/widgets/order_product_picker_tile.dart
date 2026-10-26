import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';

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
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: SizedBox(
        width: 40,
        height: 40,
        child: product.imageUrl?.isNotEmpty == true
            ? CachedNetworkImage(
                imageUrl: product.imageUrl!,
                fit: BoxFit.cover,
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
    child: HugeIcon(
      icon: HugeIcons.strokeRoundedShoppingBag01,
      size: 20,
      color: AppColor.primaryColor,
    ),
  );
}
