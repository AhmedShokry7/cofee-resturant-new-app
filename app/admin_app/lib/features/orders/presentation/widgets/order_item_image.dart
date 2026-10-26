import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class OrderItemImage extends StatelessWidget {
  const OrderItemImage({super.key, required this.item});

  final AdminOrderItem item;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: 44,
      height: 44,
      child: item.imageUrl?.trim().isNotEmpty == true
          ? CachedNetworkImage(
              imageUrl: item.imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _placeholder(context),
            )
          : _placeholder(context),
    ),
  );

  Widget _placeholder(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    return ColoredBox(
      color: dark ? AppColor.darkSurfaceContainer : AppColor.adminTableHeader,
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedShoppingBag01,
        size: 18,
        color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
      ),
    );
  }
}
