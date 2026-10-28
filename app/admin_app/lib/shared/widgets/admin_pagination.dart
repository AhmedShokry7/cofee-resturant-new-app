import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';

/// The footer of a paginated admin table.
///
/// The caller supplies [labelBuilder] so every page can format the visible
/// range with its own wording and numerals.
class AdminPagination extends StatelessWidget {
  const AdminPagination({
    super.key,
    required this.page,
    required this.pages,
    required this.count,
    required this.labelBuilder,
    required this.onChanged,
    required this.pageSize,
  });

  final int page;
  final int pages;
  final int count;
  final int pageSize;
  final String Function(int from, int to, int count) labelBuilder;
  final ValueChanged<int> onChanged;

  /// ارتفاع التذييل كاملًا: حشوه العلوي زائد مربّع الأزرار الذي يطول سطره.
  ///
  /// من يعبّ جدولًا بمساحة شاشته يخصم هذا الرقم قبل أن يحكم كم صفًا يدخل،
  /// وإلا نزلت الصفوف خلف التذييل بدل أن تنتهي قبله.
  static const double extent = AppSpacing.lg + AppSizes.px28;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColor.darkTextSecondary
        : AppColor.paginationIdleInk;
    return LayoutBuilder(
      builder: (context, constraints) {
        final first = count == 0 ? 0 : page * pageSize + 1;
        final last = (page + 1) * pageSize < count
            ? (page + 1) * pageSize
            : count;
        final label = Text(
          localizeDigits(labelBuilder(first, last, count)),
          textAlign: TextAlign.start,
          style: TextStyle(
            color: muted,
            fontSize: AppFontSizes.size10,
            fontWeight: AppFontWeights.regular,
            height: AppTextHeights.line1_5,
          ),
        );
        final controls = _PaginationControls(
          page: page,
          pages: pages,
          compact: constraints.maxWidth < 420,
          onChanged: onChanged,
        );
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: dark ? AppColor.darkBorder : AppColor.adminRowBorder,
              ),
            ),
          ),
          child: constraints.maxWidth < 620
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: label,
                    ),
                    const SizedBox(height: AppSizes.px8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: controls,
                    ),
                  ],
                )
              : Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(children: [controls, const Spacer(), label]),
                ),
        );
      },
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.page,
    required this.pages,
    required this.onChanged,
    this.compact = false,
  });

  final int page;
  final int pages;
  final ValueChanged<int> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _PaginationArrow(
        icon: AppIcons.arrowLeft01,
        tooltip: S.previousPage,
        enabled: page > 0,
        onTap: () => onChanged(page - 1),
      ),
      const SizedBox(width: AppSizes.px4),
      for (final number in _pageNumbers(page, pages, compact))
        number == null
            ? SizedBox(
                width: AppSizes.px24,
                child: Text(
                  '…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColor.darkTextSecondary
                        : AppColor.paginationIdleInk,
                    fontSize: AppFontSizes.size10,
                  ),
                ),
              )
            : _pageButton(context, number),
      const SizedBox(width: AppSizes.px4),
      _PaginationArrow(
        icon: AppIcons.arrowRight01,
        tooltip: S.nextPage,
        enabled: page + 1 < pages,
        onTap: () => onChanged(page + 1),
      ),
    ],
  );

  Widget _pageButton(BuildContext context, int number) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = page + 1 == number;
    return InkWell(
      onTap: () => onChanged(number - 1),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 27,
        height: 27,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColor.adminAccentSurface : AppColor.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          localizeDigits(number.toString()),
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: selected
                ? AppColor.adminAccent
                : dark
                ? AppColor.darkTextSecondary
                : AppColor.paginationMutedInk,
            fontSize: AppFontSizes.size10,
            fontWeight: selected ? AppFontWeights.bold : AppFontWeights.regular,
            height: AppTextHeights.line1_5,
          ),
        ),
      ),
    );
  }

  List<int?> _pageNumbers(int page, int pages, bool compact) {
    if (compact) return [page + 1];
    if (pages <= 5) {
      return [for (var number = pages; number > 0; number--) number];
    }
    final current = page + 1;
    if (current <= 3) {
      return [pages, null, 3, 2, 1];
    }
    if (current >= pages - 2) {
      return [pages, pages - 1, pages - 2, null, 1];
    }
    return [pages, null, current + 1, current, current - 1, null, 1];
  }
}

class _PaginationArrow extends StatelessWidget {
  const _PaginationArrow({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = enabled
        ? (dark ? AppColor.darkTextSecondary : AppColor.paginationMutedInk)
        : (dark ? AppColor.darkBorder : AppColor.paginationDisabledInk);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: AppSizes.px28,
          height: AppSizes.px28,
          child: Center(child: AppIcon(icon, size: 16, color: color)),
        ),
      ),
    );
  }
}
