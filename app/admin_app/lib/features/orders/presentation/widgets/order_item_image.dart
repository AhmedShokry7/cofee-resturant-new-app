import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class OrderItemImage extends StatelessWidget {
  const OrderItemImage({super.key, required this.item});

  final AdminOrderItem item;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: SizedBox(
      width: AppSizes.px44,
      height: AppSizes.px44,
      child: item.imageUrl?.trim().isNotEmpty == true
          ? CachedNetworkImage(
              imageUrl: item.imageUrl!,
              fit: BoxFit.fill,
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
      child: AppIcon(
        AppIcons.shoppingBag01,
        size: 18,
        color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
      ),
    );
  }
}
