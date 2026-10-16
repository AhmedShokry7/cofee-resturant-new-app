import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/products_grid_view.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';

class SeeAllProductsArgs {
  const SeeAllProductsArgs({
    required this.title,
    required this.products,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<ProductModel> products;
}

class SeeAllProductsPage extends StatelessWidget {
  const SeeAllProductsPage({super.key, required this.args});

  static const routeName = "seeAllProductsRoute";

  final SeeAllProductsArgs args;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(args.title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (args.subtitle != null) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                SpacingTokens.lg.w,
                SpacingTokens.sm.h,
                SpacingTokens.lg.w,
                0,
              ),
              child: Text(
                args.subtitle!,
                style: AppFonts.regular14(context)
                    .copyWith(color: AppColor.greyColor),
              ),
            ),
          ],
          Expanded(
            child: args.products.isEmpty
                ? EmptyState(
                    icon: HugeIcons.strokeRoundedCoffee02,
                    title: S.noProductsFound,
                    subtitle: S.tryAgainLater,
                  )
                : ProductsGridView(products: args.products),
          ),
        ],
      ),
    );
  }
}

