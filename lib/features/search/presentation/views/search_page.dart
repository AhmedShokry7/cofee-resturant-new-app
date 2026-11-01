import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';
import 'package:new_coffee/features/search/presentation/views/widgets/search_filter_sheet.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/search_text_field.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/products_grid_view.dart';
import 'package:new_coffee/shared/widgets/shimmer/catalog_skeletons.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: SearchTextField(
                  onChanged: (value) =>
                      context.read<SearchCubit>().search(value),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              BlocBuilder<SearchCubit, SearchState>(
                builder: (context, state) {
                  return GestureDetector(
                    onTap: () => showSearchFilterSheet(context),
                    child: Container(
                      height: AppSizes.px46,
                      width: AppSizes.px46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColor.primaryColor,
                      ),
                      child: Icon(AppIcons.filter, color: AppColor.whiteColor),
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
                  icon: AppIcons.search,
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
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EmptyState(
                          icon: AppIcons.offline,
                          title: S.searchFailed,
                          subtitle: S.tryAgainLater,
                        ),
                        SizedBox(height: AppSpacing.md),
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
                  icon: AppIcons.search,
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
