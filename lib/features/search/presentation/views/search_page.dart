import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';
import 'package:new_coffee/features/search/presentation/views/widgets/search_filter_sheet.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/products_grid_view.dart';
import 'package:new_coffee/shared/widgets/shimmer/catalog_skeletons.dart';
import 'package:hugeicons/hugeicons.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  static const routeName = "searchRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.search)),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              SpacingTokens.lg.w,
              SpacingTokens.md.h,
              SpacingTokens.lg.w,
              SpacingTokens.md.h,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) =>
                        context.read<SearchCubit>().search(value),
                    style: AppFonts.regular16(context),
                    cursorColor: AppColor.primaryColor,
                    decoration: InputDecoration(
                      hintText: S.searchHint,
                      hintStyle: AppFonts.regular14(context)
                          .copyWith(color: AppColor.greyColor),
                      prefixIcon: Icon(Icons.search, color: AppColor.greyColor),
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
                SizedBox(width: SpacingTokens.md.w),
                BlocBuilder<SearchCubit, SearchState>(
                  builder: (context, state) {
                    return GestureDetector(
                      onTap: () => showSearchFilterSheet(context),
                      child: Container(
                        height: 52.h,
                        width: 52.h,
                        decoration: BoxDecoration(
                          color: AppColor.primaryColor,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Icon(
                          HugeIcons.strokeRoundedFilterHorizontal,
                          color: AppColor.whiteColor,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<SearchCubit, SearchState>(
              builder: (context, state) {
                // Idle: the customer has not searched yet. An inviting prompt,
                // never "no results".
                if (!state.hasSearched) {
                  return EmptyState(
                    icon: HugeIcons.strokeRoundedSearch01,
                    title: S.searchPromptTitle,
                    subtitle: S.searchPromptHint,
                  );
                }

                // Show skeleton grid while search is in progress. The search
                // field row above stays visible so the layout never jumps.
                if (state.isLoading) {
                  return const ProductsGridSkeleton();
                }

                // A failure shows what happened plus a retry, so an outage
                // never looks like "no results" and never dead-ends.
                if (state.error != null) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(SpacingTokens.lg.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          EmptyState(
                            icon: Icons.cloud_off_outlined,
                            title: S.searchFailed,
                            subtitle: state.error,
                          ),
                          SizedBox(height: SpacingTokens.md.h),
                          CustomBtn(
                            text: S.retry,
                            onPressed: () =>
                                context.read<SearchCubit>().search(state.query),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Show "No results found" when search completed with no results
                if (state.isEmptyResult) {
                  return EmptyState(
                    icon: Icons.search,
                    title: S.noResults,
                    subtitle: S.tryDifferentKeyword,
                  );
                }

                // Show actual search results
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
