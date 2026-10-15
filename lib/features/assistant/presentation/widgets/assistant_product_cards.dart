import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';

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
              child: Container(
                margin: EdgeInsets.only(bottom: SpacingTokens.xs.h),
                padding: EdgeInsets.all(SpacingTokens.sm.w),
                decoration: BoxDecoration(
                  color: AppColor.whiteColor,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColor.borderColor),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: Image.asset(
                        product.image,
                        height: 40.w,
                        width: 40.w,
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(width: SpacingTokens.sm.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: AppFonts.semiBold16(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            Formatters.price(product.price),
                            style: AppFonts.regular12(context).copyWith(
                              color: AppColor.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        context.read<AssistantCubit>().recordProductInterest(product);
                        try {
                          context.read<CartCubit>().add(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("${product.name} added to cart")),
                          );
                        } catch (_) {
                          // Cart is optional here; the card tap still opens details.
                        }
                      },
                      child: Container(
                        height: 32.w,
                        decoration: const BoxDecoration(
                          color: AppColor.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          HugeIcons.strokeRoundedAdd01,
                          size: 18.w,
                          color: AppColor.whiteColor,
                        ),
                      ),
                    ),
                    SizedBox(width: SpacingTokens.xs.w),
                    Icon(
                      HugeIcons.strokeRoundedArrowRight01,
                      size: 18.w,
                      color: AppColor.greyColor,
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}