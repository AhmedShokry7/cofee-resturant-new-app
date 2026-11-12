import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

class ProductFavoriteButton extends StatelessWidget {
  const ProductFavoriteButton({
    super.key,
    required this.product,
    this.size = AppDimensions.favoriteButtonCard,
  });

  final ProductModel product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isFavorite = context.watch<FavoritesCubit>().state.ids.contains(
      product.id,
    );

    return GestureDetector(
      onTap: () => context.read<FavoritesCubit>().toggle(product.id),
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: AppColor.whiteColor.withValues(alpha: 0.7),
          shape: BoxShape.circle,
        ),
        // Inactive: outlined heart in grey. Active: the heart itself is the
        // colour — a filled red heart, not a red circle around it. hugeicons
        // ships no filled heart, hence the Material filled icon.
        child: Icon(
          isFavorite ? Icons.favorite : AppIcons.favourite,
          size: (size * 0.55),
          color: isFavorite ? AppColor.errorColor : AppColor.greyColor,
        ),
      ),
    );
  }
}
