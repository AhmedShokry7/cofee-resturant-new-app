import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

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
    this.pageSize = 5,
  });

  final int page;
  final int pages;
  final int count;
  final int pageSize;
  final String Function(int from, int to, int count) labelBuilder;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final first = count == 0 ? 0 : page * pageSize + 1;
        final last = (page + 1) * pageSize < count
            ? (page + 1) * pageSize
            : count;
        final label = Text(
          labelBuilder(first, last, count),
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Color(0xFF8A968E),
            fontSize: 10,
            fontWeight: FontWeight.w400,
            height: 1.5,
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
          padding: const EdgeInsets.only(top: 16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColor.adminRowBorder)),
          ),
          child: constraints.maxWidth < 620
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.centerRight, child: label),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerLeft, child: controls),
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
        icon: HugeIcons.strokeRoundedArrowLeft01,
        tooltip: S.previousPage,
        enabled: page > 0,
        onTap: () => onChanged(page - 1),
      ),
      const SizedBox(width: 4),
      for (final number in _pageNumbers(page, pages, compact))
        number == null
            ? const SizedBox(
                width: 24,
                child: Text(
                  '…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF8A968E), fontSize: 10),
                ),
              )
            : _pageButton(number),
      const SizedBox(width: 4),
      _PaginationArrow(
        icon: HugeIcons.strokeRoundedArrowRight01,
        tooltip: S.nextPage,
        enabled: page + 1 < pages,
        onTap: () => onChanged(page + 1),
      ),
    ],
  );

  Widget _pageButton(int number) {
    final selected = page + 1 == number;
    return InkWell(
      onTap: () => onChanged(number - 1),
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 27,
        height: 27,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColor.adminAccentSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          number.toString(),
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: selected ? AppColor.adminAccent : const Color(0xFF758178),
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            height: 1.5,
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
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        width: 27,
        height: 27,
        child: Center(
          child: HugeIcon(
            icon: icon,
            size: 16,
            color: enabled ? const Color(0xFF758178) : const Color(0x59758178),
          ),
        ),
      ),
    ),
  );
}
