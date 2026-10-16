import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/search/data/model/search_sort.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

Future<void> showSearchFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColor.whiteColor,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
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
        padding: EdgeInsets.all(SpacingTokens.lg.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4.h,
                width: 100.w,
                decoration: BoxDecoration(
                  color: AppColor.borderColor,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            SizedBox(height: SpacingTokens.lg.h),
            Text(S.filters, style: AppFonts.semiBold18(context)),
            SizedBox(height: SpacingTokens.lg.h),
            Text(S.sortBy, style: AppFonts.medium16(context)),
            SizedBox(height: SpacingTokens.sm.h),
            Wrap(
              spacing: SpacingTokens.sm.w,
              runSpacing: SpacingTokens.sm.h,
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
            SizedBox(height: SpacingTokens.lg.h),
            Text(S.category, style: AppFonts.medium16(context)),
            SizedBox(height: SpacingTokens.sm.h),
            Wrap(
              spacing: SpacingTokens.sm.w,
              runSpacing: SpacingTokens.sm.h,
              children: [
                _ChoiceChip(
                  label: S.all,
                  selected: _categoryId == null,
                  onTap: () => setState(() => _categoryId = null),
                ),
                ...context.read<SearchCubit>().state.categories.map((
                  CategoryModel category,
                ) {
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
            SizedBox(height: SpacingTokens.lg.h),
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
            SizedBox(height: SpacingTokens.lg.h),
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
                SizedBox(width: SpacingTokens.md.w),
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
          horizontal: SpacingTokens.md.w,
          vertical: SpacingTokens.sm.h,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColor.primaryColor : AppColor.lightGreyColor,
          borderRadius: BorderRadius.circular(100.r),
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
