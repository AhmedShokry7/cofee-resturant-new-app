import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/products_grid_view.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  static const routeName = "searchRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search")),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(SpacingTokens.lg.w),
            child: TextField(
              onChanged: (value) => context.read<SearchCubit>().search(value),
              style: AppFonts.regular16(context),
              cursorColor: AppColor.primaryColor,
              decoration: InputDecoration(
                hintText: "Search coffee...",
                hintStyle: AppFonts.regular14(
                  context,
                ).copyWith(color: AppColor.greyColor),
                prefixIcon: Icon(
                  HugeIcons.strokeRoundedSearch01,
                  color: AppColor.greyColor,
                ),
                filled: true,
                fillColor: AppColor.lightGreyColor,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: SpacingTokens.lg.w,
                  vertical: SpacingTokens.md.h,
                ),
                border: _border(),
                enabledBorder: _border(),
                focusedBorder: _border(color: AppColor.primaryColor),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<SearchCubit, SearchState>(
              builder: (context, state) {
                if (state.results.isEmpty) {
                  return const EmptyState(
                    icon: HugeIcons.strokeRoundedSearch01,
                    title: "No results found",
                    subtitle: "Try a different keyword",
                  );
                }
                return ProductsGridView(products: state.results);
              },
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _border({Color? color}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(100.r),
      borderSide: BorderSide(color: color ?? Colors.transparent),
    );
  }
}
