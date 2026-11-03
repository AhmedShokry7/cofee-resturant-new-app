import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// عنصر قابل للانتقاء في [AdminPickableList]: معرّف للكتابة، وسطر اسم، وسطر
/// ثانٍ هادئ إن كان للعنصر ما يُميَّز به (فئة المنتج، عدد منتجات الفئة...).
class AdminPickableItem {
  const AdminPickableItem({
    required this.id,
    required this.name,
    this.caption,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? caption;

  /// العنصر معطَّل في القاعدة؛ يبقى قابلًا للانتقاء لأن الصفّ نفسه قد يكون
  /// محفوظًا، لكن السطر يوضّح ذلك بدل أن يُفهم خطأ.
  final bool isActive;
}

/// قائمة بحث وتحديد متعدّدة تُضمَّن في الشاشة نفسها، لا في حوار فوق حوار.
///
///كانت كل صفحة تكتب مُنتقى منتجاتها خاصّة بها؛ هنا يكتفي المستدعي بالعناصر
/// والانتقاء، فتبقى السطور والقواعد (البحث في الاسم والسطر الثاني، عدّاد
/// المحدَّد، جملا «لا شيء يطابق» و«لا توجد عناصر») في مكان واحد.
class AdminPickableList extends StatefulWidget {
  const AdminPickableList({
    super.key,
    required this.title,
    required this.items,
    required this.selectedIds,
    required this.onChanged,
    this.height = 200,
  });

  final String title;
  final List<AdminPickableItem> items;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  /// ارتفاع قائمة السطور؛ الإطار الخارجي يتبعه حتى لا يقفز الحوار حين تتغيّر
  /// كلمة البحث.
  final double height;

  @override
  State<AdminPickableList> createState() => _AdminPickableListState();
}

class _AdminPickableListState extends State<AdminPickableList> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AdminPickableItem> get _visible {
    final term = _search.text.trim().toLowerCase();
    if (term.isEmpty) return widget.items;
    return widget.items
        .where(
          (item) =>
              item.name.toLowerCase().contains(term) ||
              (item.caption?.toLowerCase().contains(term) ?? false),
        )
        .toList(growable: false);
  }

  void _toggle(String id) {
    final next = <String>{...widget.selectedIds};
    if (!next.remove(id)) next.add(id);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visible;
    final selected = widget.selectedIds;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: adminControlBorderColor(theme)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminHeadingColor(theme),
                      fontSize: AppFontSizes.size10_5,
                      fontWeight: AppFontWeights.semiBold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ),
                Text(
                  localizeDigits(S.scopeSelectedCount(selected.length)),
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextField(
              key: Key('admin-pickable-search-${widget.title}'),
              controller: _search,
              style: TextStyle(fontSize: AppFontSizes.size11),
              decoration: InputDecoration(
                isDense: true,
                hintText: S.search,
                prefixIcon: const Icon(AppIcons.search01, size: 16),
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Divider(height: 1, color: adminRowBorderColor(theme)),
          SizedBox(
            height: widget.height,
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        widget.items.isEmpty
                            ? S.nothingToChooseFrom
                            : S.nothingMatchesSearch,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size10_5,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: adminRowBorderColor(theme)),
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      final checked = selected.contains(item.id);
                      // السطر الثاني: ما يميّز العنصر، أو كونه معطَّلًا حين لا
                      // شيء يميّزه، حتى لا يُنتقى عنصرٌ لا يراه العميل.
                      final caption =
                          item.caption ?? (item.isActive ? null : S.inactive);
                      return CheckboxListTile(
                        key: Key('admin-pickable-${item.id}'),
                        value: checked,
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: adminBodyColor(theme),
                            fontSize: AppFontSizes.size11,
                            height: AppTextHeights.line1_4,
                          ),
                        ),
                        subtitle: caption == null
                            ? null
                            : Text(
                                localizeDigits(caption),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: adminMutedColor(theme),
                                  fontSize: AppFontSizes.size9,
                                  height: AppTextHeights.line1_4,
                                ),
                              ),
                        onChanged: (_) => _toggle(item.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
