import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/search/data/model/search_sort.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/shared/widgets/sheet_handle.dart';
import 'package:new_coffee/core/theme/tokens.dart';

Future<void> showSearchFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColor.cardSurface,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r32)),
    ),
    builder: (context) => const SearchFilterSheet(),
  );
}

class SearchFilterSheet extends StatefulWidget {
  const SearchFilterSheet({super.key});

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  late final double _minBound;
  late final double _maxBound;
  late SearchSort _sort;
  String? _categoryId;
  late RangeValues _prices;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<SearchCubit>();
    final prices = cubit.priceBounds();
    // Bounds come from the loaded results, not from scanning the whole
    // catalogue. The old version walked getMenuList() and called reduce() on it,
    // which threw on an empty menu.
    _minBound = prices.first;
    _maxBound = prices.last;

    final state = cubit.state;
    _sort = state.sort;
    _categoryId = state.category;
    _prices = RangeValues(
      state.minPrice ?? _minBound,
      state.maxPrice ?? _maxBound,
    );
  }

  void _apply() {
    context.read<SearchCubit>().applyFilters(
      sort: _sort,
      category: _categoryId,
      minPrice: _prices.start,
      maxPrice: _prices.end,
    );
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _sort = SearchSort.relevance;
      _categoryId = null;
      _prices = RangeValues(_minBound, _maxBound);
    });
    context.read<SearchCubit>().resetFilters();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            SizedBox(height: AppSpacing.lg),
            Text(S.filters, style: AppFonts.semiBold18(context)),
            SizedBox(height: AppSpacing.lg),
            Text(S.sortBy, style: AppFonts.medium16(context)),
            SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: SearchSort.values
                  .map(
                    (sort) => _ChoiceChip(
                      label: sort.label,
                      selected: _sort == sort,
                      onTap: () => setState(() => _sort = sort),
                    ),
                  )
                  .toList(),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(S.category, style: AppFonts.medium16(context)),
            SizedBox(height: AppSpacing.sm),
            // The categories arrive on their own request, so the chips rebuild
            // from the cubit instead of being read once: a plain context.read
            // here kept the section on whatever the first frame held, which was
            // often nothing.
            BlocBuilder<SearchCubit, SearchState>(
              buildWhen: (previous, current) =>
                  previous.categories != current.categories,
              builder: (context, state) => Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _ChoiceChip(
                    label: S.all,
                    selected: _categoryId == null,
                    onTap: () => setState(() => _categoryId = null),
                  ),
                  ...state.categories.map((CategoryModel category) {
                    final id = category.id;
                    if (id == null) {
                      // Without an id this chip could only send a display
                      // label, which the RPC would treat as an id and match
                      // nothing. Skip it rather than offer a filter that lies.
                      return const SizedBox.shrink();
                    }
                    return _ChoiceChip(
                      label: category.label,
                      selected: _categoryId == id,
                      onTap: () => setState(() => _categoryId = id),
                    );
                  }),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(S.priceRange, style: AppFonts.medium16(context)),
            RangeSlider(
              values: _prices,
              min: _minBound,
              max: _maxBound,
              activeColor: AppColor.primaryColor,
              labels: RangeLabels(
                Formatters.price(_prices.start),
                Formatters.price(_prices.end),
              ),
              onChanged: (values) => setState(() => _prices = values),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PriceLabel(
                  amount: _prices.start,
                  style: AppFonts.regular12(context)
                      .copyWith(color: AppColor.greyColor),
                  iconSize: 12,
                  iconColor: AppColor.greyColor,
                ),
                PriceLabel(
                  amount: _prices.end,
                  style: AppFonts.regular12(context)
                      .copyWith(color: AppColor.greyColor),
                  iconSize: 12,
                  iconColor: AppColor.greyColor,
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: CustomBtn(
                    text: S.reset,
                    variant: BtnVariant.secondary,
                    textColor: AppColor.primaryColor,
                    onPressed: _reset,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: CustomBtn(text: S.apply, onPressed: _apply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColor.primaryColor : AppColor.lightGreyColor,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppFonts.medium12(context).copyWith(
            color: selected ? AppColor.whiteColor : AppColor.greyColor,
          ),
        ),
      ),
    );
  }
}
