import 'package:new_coffee/shared/widgets/design_text.dart';
import 'package:material_ui/material_ui.dart';
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
import 'package:new_coffee/shared/widgets/app_back_button.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  static const routeName = "searchRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: DesignText(S.search, page: 'search', label: 'search'),
      ),
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
                  return Semantics(
                    button: true,
                    label: S.filters,
                    child: Material(
                      color: AppColor.cardSurface,
                      borderRadius: BorderRadius.circular(AppRadius.r16),
                      child: InkWell(
                        onTap: () => showSearchFilterSheet(context),
                        borderRadius: BorderRadius.circular(AppRadius.r16),
                        child: Container(
                          height: AppSizes.px46,
                          width: AppSizes.px46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.r16),
                            border: Border.all(color: AppColor.borderColor),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                AppIcons.filter,
                                color: AppColor.primaryColor,
                              ),
                              if (state.hasActiveFilters)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: AppSizes.px8,
                                    height: AppSizes.px8,
                                    decoration: BoxDecoration(
                                      color: AppColor.primaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColor.cardSurface,
                                        width: AppSizes.px1_5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
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
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl * AppSpacing.xxs,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: AppSizes.px76,
                          height: AppSizes.px76,
                          decoration: BoxDecoration(
                            color: AppColor.lightGreyColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            AppIcons.search,
                            size: AppSpacing.xl,
                            color: AppColor.primaryColor,
                          ),
                        ),
                        SizedBox(height: AppSpacing.lg),
                        Text(
                          S.searchPromptTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          S.searchPromptHint,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColor.textSecondary),
                        ),
                      ],
                    ),
                  ),
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
                if (state.hasMore) {
                  if (state.isLoadingMore) {
                    return const ProductsGridSkeleton();
                  }
                  return Center(
                    child: CustomBtn(
                      text: S.loadMore,
                      onPressed: () => context.read<SearchCubit>().loadMore(),
                    ),
                  );
                }
                return EmptyState(
                  icon: AppIcons.search,
                  title: S.noResults,
                  subtitle: S.tryDifferentKeyword,
                );
              }

              return ProductsGridView(
                products: state.results,
                resetKey:
                    '${state.query}|${state.category}|${state.minPrice}|${state.maxPrice}|${state.sort}',
                hasMore: state.hasMore,
                isLoadingMore: state.isLoadingMore,
                onLoadMore: context.read<SearchCubit>().loadMore,
              );
            },
          ),
        ),
      ],
    );
  }
}
