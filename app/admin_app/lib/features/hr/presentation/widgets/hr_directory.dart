import 'dart:math' as math;

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:flutter/material.dart';

/// جدول قائمة إدارية واحدة لكل أسطح HR: ترويسة، وصفوف بأعمدة مشتركة القياس،
/// وبطاقات على الشاشة الضيقة، وتذييل ترقيم.
///
/// السطر لا يعرف ماذا يمثّل: الأعمدة من صفحته والخلايا من صفحته. أما ما كان
/// يتكرّر في كل شاشة — عرض العمود، حدود الصف، التذييل، والبديل الضيق — فيُكتب
/// هنا مرة واحدة، فلا يختلف جدول حضور عن جدول إجازة بتفاصيل تصميم.
class HrDirectory<T> extends StatefulWidget {
  const HrDirectory({
    super.key,
    required this.items,
    required this.columns,
    required this.cellsOf,
    required this.cardOf,
    required this.searchOf,
    required this.search,
    required this.emptyLabel,
    this.onTap,
    this.pageSize = 8,
    this.actionsOf,
  });

  final List<T> items;

  /// عناوين الأعمدة، وقياسها هو قياس خلايا الصف نفسها.
  final List<String> columns;

  final List<Widget> Function(BuildContext context, T item) cellsOf;
  final Widget Function(BuildContext context, T item) cardOf;

  /// أزرار القرار في نهاية الصف الواسع، وخالية لسطر لا قرار عليه.
  ///
  /// الجدول الواسع كان يرسم `cellsOf` وحدها، فيحرم المدير من اعتماد طلب أو
  /// رفضه على الشاشة التي يعمل عليها أكثر وقتِه؛ البطاقة وحدها لا تكفي.
  final List<Widget> Function(BuildContext context, T item)? actionsOf;

  /// ما يبحث فيه السطر: الاسم والرقم معًا، لا عمود واحد.
  final String Function(T item) searchOf;

  /// نص البحث القادم من شريط الأدمن العلوي.
  final String search;

  final String emptyLabel;
  final ValueChanged<T>? onTap;
  final int pageSize;

  @override
  State<HrDirectory<T>> createState() => _HrDirectoryState<T>();
}

class _HrDirectoryState<T> extends State<HrDirectory<T>> {
  int _page = 0;

  List<T> get _matches {
    final query = widget.search.trim();
    if (query.isEmpty) return widget.items;
    return widget.items
        .where((item) => widget.searchOf(item).contains(query))
        .toList(growable: false);
  }

  @override
  void didUpdateWidget(HrDirectory<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search) _page = 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = _matches;
    final pages = math.max(1, (matches.length / widget.pageSize).ceil());
    if (_page >= pages) _page = pages - 1;
    final start = _page * widget.pageSize;
    final visible = matches.skip(start).take(widget.pageSize).toList();
    final narrow = MediaQuery.sizeOf(context).width < AppBreakpoints.wideLayout;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!narrow && matches.isNotEmpty) _header(theme),
        Expanded(
          child: matches.isEmpty
              ? Center(child: Text(widget.emptyLabel))
              : narrow
              ? ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      widget.cardOf(context, visible[index]),
                )
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) => _row(theme, visible[index]),
                ),
        ),
        if (matches.isNotEmpty)
          AdminPagination(
            page: _page,
            pages: pages,
            count: matches.length,
            pageSize: widget.pageSize,
            labelBuilder: S.hrRowsLabel,
            onChanged: (value) => setState(() => _page = value),
          ),
      ],
    );
  }

  Widget _header(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          for (var index = 0; index < widget.columns.length; index++)
            Expanded(
              flex: _flex(index),
              child: Text(
                widget.columns[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: adminMutedColor(theme),
                  fontSize: AppFontSizes.size9_5,
                  fontWeight: AppFontWeights.semiBold,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ),
          // عمود القرار بلا عنوان: يقابله أزرار الصف بمساحة فارغة.
          if (widget.actionsOf != null)
            const Expanded(flex: _actionsFlex, child: SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, T item) {
    final cells = widget.cellsOf(context, item);
    final actions = widget.actionsOf?.call(context, item) ?? const <Widget>[];
    return InkWell(
      onTap: widget.onTap == null ? null : () => widget.onTap!(item),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: adminRowBorderColor(theme))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var index = 0; index < cells.length; index++)
              Expanded(flex: _flex(index), child: cells[index]),
            if (actions.isNotEmpty)
              Expanded(
                flex: _actionsFlex,
                child: Wrap(
                  spacing: AppSpacing.xxs,
                  runSpacing: AppSpacing.xxs,
                  children: actions,
                ),
              )
            else if (widget.actionsOf != null)
              const Expanded(flex: _actionsFlex, child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  /// عرض العمود: أوله أعرض لأنه الاسم، والبقية يتقاسمون ما بقي.
  int _flex(int index) => index == 0 ? 3 : 2;

  /// عمود القرار أعرض قليلًا: زرّان متجاوران لا زرّ واحد.
  static const int _actionsFlex = 3;
}
