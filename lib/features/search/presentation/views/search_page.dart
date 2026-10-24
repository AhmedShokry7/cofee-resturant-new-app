import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';
import 'package:new_coffee/features/search/presentation/views/widgets/search_filter_sheet.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/search_text_field.dart';
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
      body: const _SearchView(),
    );
  }
}

class _SearchView extends StatelessWidget {
  const _SearchView();

  @override
  Widget build(BuildContext context) {
    return Column(
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
                child: SearchTextField(
                  onChanged: (value) =>
                      context.read<SearchCubit>().search(value),
                ),
              ),
              SizedBox(width: SpacingTokens.sm.w),
              BlocBuilder<SearchCubit, SearchState>(
                builder: (context, state) {
                  return GestureDetector(
                    onTap: () => showSearchFilterSheet(context),
                    child: Container(
                      height: 46.h,
                      width: 46.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColor.primaryColor,
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
              if (!state.hasSearched) {
                return EmptyState(
                  icon: HugeIcons.strokeRoundedSearch01,
                  title: S.searchPromptTitle,
                  subtitle: S.searchPromptHint,
                );
              }

              if (state.isLoading) {
                return const ProductsGridSkeleton();
              }

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
                          subtitle: S.tryAgainLater,
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

              if (state.isEmptyResult) {
                return EmptyState(
                  icon: Icons.search,
                  title: S.noResults,
                  subtitle: S.tryDifferentKeyword,
                );
              }

              return ProductsGridView(products: state.results);
            },
          ),
        ),
      ],
    );
  }
}
