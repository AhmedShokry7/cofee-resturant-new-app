import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/pos/data/models/pos_catalog.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

class PosMenuToolbar extends StatelessWidget {
  const PosMenuToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.categories,
    required this.categoryId,
    required this.onCategoryChanged,
    required this.totalProducts,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<PosCategory> categories;
  final String? categoryId;
  final ValueChanged<String?> onCategoryChanged;
  final int totalProducts;

  @override
  Widget build(BuildContext context) {
    final search = AdminSearchField(
      controller: searchController,
      onChanged: onSearchChanged,
      hintText: S.posSearchHint,
    );

    final rail = _CategoryRail(
      categories: categories,
      categoryId: categoryId,
      totalProducts: totalProducts,
      onCategoryChanged: onCategoryChanged,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (wide)
                  SizedBox(width: 360, child: search)
                else
                  Expanded(child: search),
                if (wide) ...[
                  const SizedBox(width: 12),
                  Text(
                    S.categoriesCount(categories.length),
                    style: TextStyle(
                      color: adminMutedColor(Theme.of(context)),
                      fontSize: AppFontSizes.size10,
                      fontWeight: AppFontWeights.semiBold,
                    ),
                  ),
                  const Spacer(),
                ],
              ],
            ),
            if (categories.isNotEmpty) ...[const SizedBox(height: 10), rail],
          ],
        );
      },
    );
  }
}

class _CategoryRail extends StatefulWidget {
  const _CategoryRail({
    required this.categories,
    required this.categoryId,
    required this.totalProducts,
    required this.onCategoryChanged,
  });

  final List<PosCategory> categories;
  final String? categoryId;
  final int totalProducts;
  final ValueChanged<String?> onCategoryChanged;

  @override
  State<_CategoryRail> createState() => _CategoryRailState();
}

class _CategoryRailState extends State<_CategoryRail> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Mouse wheels only report a vertical delta; translate it to the rail's
  /// horizontal axis so the categories can be scrolled on web and desktop.
  /// Horizontal trackpad deltas are left to the list itself.
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final dy = event.scrollDelta.dy;
    if (dy == 0 || event.scrollDelta.dx != 0) return;
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final target = (position.pixels + dy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return;
    _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final language = AppLocale.instance.language;
    return SizedBox(
      height: 68,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          dragDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
            PointerDeviceKind.invertedStylus,
          },
        ),
        child: Scrollbar(
          controller: _controller,
          thickness: 4,
          radius: const Radius.circular(999),
          child: Listener(
            onPointerSignal: _handlePointerSignal,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              primary: false,
              padding: const EdgeInsets.only(bottom: 6),
              itemCount: widget.categories.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _CategoryCard(
                    label: S.posAllCategories,
                    count: widget.totalProducts,
                    selected: widget.categoryId == null,
                    icon: HugeIcons.strokeRoundedDashboardSquare01,
                    onTap: () => widget.onCategoryChanged(null),
                  );
                }
                final category = widget.categories[index - 1];
                return _CategoryCard(
                  label: category.nameFor(language),
                  count: category.productCount,
                  selected: category.id == widget.categoryId,
                  imageUrl: category.imageUrl,
                  onTap: () => widget.onCategoryChanged(category.id),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.imageUrl,
    this.icon,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final String? imageUrl;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? adminFlagForeground(theme, AppColor.adminAccent)
        : adminHeadingColor(theme);

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, ${S.productsCount(count)}',
      child: Material(
        color: selected
            ? adminFlagBackground(
                theme,
                AppColor.adminAccent,
                AppColor.adminAccentSurface,
              )
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 152,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColor.adminAccent.withValues(alpha: .45)
                    : adminCardBorderColor(theme),
              ),
            ),
            child: Row(
              children: [
                AdminNetworkThumb(
                  imageUrl: imageUrl,
                  size: 46,
                  icon: icon ?? HugeIcons.strokeRoundedCoffee01,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: AppFontSizes.size10_5,
                          fontWeight: selected
                              ? AppFontWeights.bold
                              : AppFontWeights.semiBold,
                          height: AppTextHeights.line1_35,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        localizeDigits('$count'),
                        style: TextStyle(
                          color: selected
                              ? foreground.withValues(alpha: .8)
                              : adminMutedColor(theme),
                          fontSize: AppFontSizes.size9,
                          fontWeight: AppFontWeights.semiBold,
                          height: AppTextHeights.line1_3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
