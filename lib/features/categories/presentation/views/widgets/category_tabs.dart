import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/shared/widgets/shimmer/catalog_skeletons.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The row of category names at the top of the categories page.
///
/// The selected name is moved into view. The home row of circles chooses a tab
/// here without the customer ever seeing the strip, so a category picked from
/// the eighth position of the marquee would otherwise sit off screen with its
/// products showing and nothing on the bar to say which one they belong to.
class CategoryTabs extends StatefulWidget {
  const CategoryTabs({super.key});

  @override
  State<CategoryTabs> createState() => _CategoryTabsState();
}

class _CategoryTabsState extends State<CategoryTabs> {
  /// Where a revealed name stops: a little way in from the leading edge, so a
  /// neighbour stays visible beside it and the row does not look like it ran out.
  static const double _revealAlignment = 0.2;

  /// One key per name, held by the id of its category.
  ///
  /// A name is as wide as its own text, so the place a tab sits at cannot be
  /// worked out from the index; the name that has to be shown is found through
  /// its key instead.
  final Map<String, GlobalKey> _pills = {};

  /// The name already moved into view, so a rebuild of the same choice does not
  /// start another scroll.
  String? _revealed;

  GlobalKey _pillFor(String identity) =>
      _pills.putIfAbsent(identity, () => GlobalKey());

  /// Shows [identity] in the strip once the frame holding it is on screen.
  ///
  /// A name that is already whole on screen does not move: `ensureVisible` only
  /// scrolls when the range it is given lies outside what is visible.
  void _reveal(String identity) {
    if (_revealed == identity) return;
    _revealed = identity;
    final key = _pillFor(identity);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = key.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(context, alignment: _revealAlignment);
    });
  }

  /// What sets one name among the others. The id is the row's own; the slug is
  /// the fallback on the legacy rows that have neither, and a row with none of
  /// them is still the row sitting at that position.
  static String _identityOf(CategoryModel category, int index) =>
      category.id ?? category.slug ?? 'tab-$index';

  @override
  Widget build(BuildContext context) {
    // Categories now come from the cubit. The old version called
    // getCategoriesList() here, which meant the tabs were fixed at compile time
    // and could never reflect an admin change.
    return BlocBuilder<CategoriesCubit, CategoriesState>(
      builder: (context, state) {
        final categories = state.categories;
        if (categories.isEmpty) {
          // While the first page loads, shimmer tab pills keep the
          // [AppDimensions.tabBarHeight] bar laid out exactly as the loaded
          // tabs will be.
          if (state.isLoading) return const CategoryTabsSkeleton();
          return SizedBox(height: AppDimensions.tabBarHeight);
        }

        final current = state.index.clamp(0, categories.length - 1);
        _reveal(_identityOf(categories[current], current));

        return Container(
          height: AppDimensions.tabBarHeight,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColor.borderColor)),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemBuilder: (context, index) {
              final isSelected = index == current;
              return GestureDetector(
                key: _pillFor(_identityOf(categories[index], index)),
                onTap: () => context.read<CategoriesCubit>().select(index),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Center(
                            child: Text(
                              categories[index].label,
                              style: AppFonts.medium16(context).copyWith(
                                color: isSelected
                                    ? AppColor.primaryColor
                                    : AppColor.greyColor,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          height: AppSizes.px3,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColor.primaryColor
                                : AppColor.transparent,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppRadius.r8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
