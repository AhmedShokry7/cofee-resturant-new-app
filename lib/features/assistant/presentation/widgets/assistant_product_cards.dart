import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_card.dart';

Widget assistantProductCards({
  required BuildContext context,
  required AssistantCubit cubit,
}) {
  return BlocBuilder<AssistantCubit, AssistantState>(
    builder: (context, state) {
      if (state.products.isEmpty) return const SizedBox.shrink();
      return Column(
        children: [
          for (final product in state.products)
            GestureDetector(
              onTap: () {
                cubit.recordProductInterest(product);
                Navigator.of(context).pop();
                rootNavigatorKey.currentState?.pushNamed(
                  ProductDetailsPage.routeName,
                  arguments: product,
                );
              },
              child: ProductCard(
                product: product,
                showFavorite: false,
              ),
            ),
        ],
      );
    },
  );
}