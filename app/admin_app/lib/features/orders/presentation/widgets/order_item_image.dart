import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';

class OrderItemImage extends StatelessWidget {
  const OrderItemImage({super.key, required this.item});
  final AdminOrderItem item;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
    child: SizedBox(
      width: 48,
      height: 48,
      child: item.imageUrl?.trim().isNotEmpty == true
          ? CachedNetworkImage(
              imageUrl: item.imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _placeholder(),
            )
          : _placeholder(),
    ),
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
