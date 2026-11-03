import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_spec.dart';
import 'package:admin_app/features/customer_preview/domain/services/design_tree.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/builder_drag.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/builder_drag_feedback.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// أوامر الشجرة على طبقة واحدة: تجمع نداءات المحرّر حتى لا يتفرّع كل أمر خاصًا
/// به في كل لوحة.
class BuilderCommands {
  const BuilderCommands({
    required this.select,
    required this.drop,
    required this.toggleVisible,
    required this.duplicate,
    required this.remove,
    required this.rename,
    required this.move,
  });

  final ValueChanged<String?> select;

  /// إفلات: الطبقة الممسوكة، وأبوها الجديد، وموضعها في قائمة أبنائه.
  final void Function(BuilderDrag drag, String parentId, int index) drop;

  final ValueChanged<String> toggleVisible;
  final ValueChanged<String> duplicate;
  final ValueChanged<String> remove;

  /// اسم جديد للطبقة، مع سبب الرفض إن رُفض (نص [DesignEditRejection.name]).
  final DesignEditRejection Function(String id, String newId) rename;

  /// نقل طبقة مواضع بين إخوتها: [delta] سالب إلى أعلى.
  final void Function(String id, int delta) move;
}

/// شجرة طبقات الصفحة: كل عقدة وأبناؤها تحتها، بالسحب والتحديد والإخفاء.
///
/// الشجرة واللوحة وجهان لتحديد واحد: ما يُضغط هنا يُحدَّد هناك، والنافلة
/// [BuilderCommands.move] و[BuilderCommands.drop] هما ما يحرّك الصفوف — فلا
/// ترتيب يُكتب في الشجرة ولا يُرى في الرسم.
class WidgetTreePanel extends StatefulWidget {
  const WidgetTreePanel({
    super.key,
    required this.document,
    required this.page,
    required this.root,
    required this.selectedId,
    required this.enabled,
    required this.commands,
  });

  final DesignDocument document;
  final AppPage page;
  final DesignNode root;
  final String? selectedId;

  /// false في وضع المشاهدة: النقر للتحديد يبقى، والأوامر كلها تتوقف.
  final bool enabled;

  final BuilderCommands commands;

  @override
  State<WidgetTreePanel> createState() => _WidgetTreePanelState();
}

class _WidgetTreePanelState extends State<WidgetTreePanel> {
  /// طبقات مطويّة: الحاوية الكاملة تُطوى ليُقرأ ما تحتها في صفحة طويلة.
  final Set<String> _collapsed = <String>{};

  AppLanguage get _language => AppLocale.instance.language;

  @override
  Widget build(BuildContext context) {
    final children = widget.root.children;
    if (children.isEmpty) {
      return Text(
        S.builderNoLayers,
        style: TextStyle(
          color: adminMutedColor(Theme.of(context)),
          fontSize: AppFontSizes.size10_5,
          fontWeight: AppFontWeights.regular,
          height: AppTextHeights.line1_5,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < children.length; index++)
          ..._branch(
            node: children[index],
            parent: widget.root,
            index: index,
            depth: 0,
          ),
      ],
    );
  }

  List<Widget> _branch({
    required DesignNode node,
    required DesignNode? parent,
    required int index,
    required int depth,
  }) {
    final spec = WidgetRegistry.of(node.type);
    final rows = <Widget>[
      _row(node: node, parent: parent, index: index, depth: depth, spec: spec),
    ];
    final folded = _collapsed.contains(node.id);
    if (!folded) {
      for (var child = 0; child < node.children.length; child++) {
        rows.addAll(
          _branch(
            node: node.children[child],
            parent: node,
            index: child,
            depth: depth + 1,
          ),
        );
      }
    }
    // حاوية مطويّة تُخبّر كم ابنًا أخفته، حتى لا يُظنّ أنها فارغة.
    if (folded && node.children.isNotEmpty) {
      rows.add(
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: AppDimensions.builderTreeIndent * (depth + 1),
            top: AppSpacing.xxs,
            bottom: AppSpacing.xxs,
          ),
          child: Text(
            '${node.children.length}',
            style: TextStyle(
              color: adminSubtleColor(Theme.of(context)),
              fontSize: AppFontSizes.size9,
              fontWeight: AppFontWeights.medium,
              height: AppTextHeights.line1_3,
            ),
          ),
        ),
      );
    }
    // النوع المجهول يبقى في الشجرة: لا رسم له في اللوحة، ولا يُترك مستند بلا
    // دليل على عقدة لا يعرفها المحرّر.
    if (spec == null) {
      rows.add(
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: AppDimensions.builderTreeIndent * (depth + 1),
          ),
          child: Text(
            node.type,
            style: TextStyle(
              color: AppColor.errorColor,
              fontSize: AppFontSizes.size9,
              fontWeight: AppFontWeights.regular,
              height: AppTextHeights.line1_3,
            ),
          ),
        ),
      );
    }
    return rows;
  }

  Widget _row({
    required DesignNode node,
    required DesignNode? parent,
    required int index,
    required int depth,
    required WidgetSpec? spec,
  }) {
    final locked = DesignTree.isLocked(node.type);
    final draggable = widget.enabled && !locked;
    return DragTarget<BuilderDrag>(
      key: ValueKey('tree-${node.id}'),
      onWillAcceptWithDetails: (details) =>
          _dropTarget(drag: details.data, node: node, parent: parent, index: index) !=
          null,
      onAcceptWithDetails: (details) {
        final target = _dropTarget(
          drag: details.data,
          node: node,
          parent: parent,
          index: index,
        );
        if (target == null) return;
        widget.commands.drop(
          details.data,
          target.parentId,
          target.indexFor(details.data),
        );
      },
      builder: (context, candidates, _) => _Row(
        node: node,
        label: spec?.name.of(_language) ?? node.type,
        depth: depth,
        selected: node.id == widget.selectedId,
        hidden: !node.isVisible,
        locked: locked,
        draggable: draggable,
        hot: candidates.isNotEmpty,
        canFold: node.children.isNotEmpty,
        folded: _collapsed.contains(node.id),
        enabled: widget.enabled,
        language: _language,
        onSelect: () => widget.commands.select(node.id),
        onFold: () => setState(() {
          if (_collapsed.contains(node.id)) {
            _collapsed.remove(node.id);
          } else {
            _collapsed.add(node.id);
          }
        }),
        onToggleVisible: () => widget.commands.toggleVisible(node.id),
        onDuplicate: () => widget.commands.duplicate(node.id),
        onRemove: () => widget.commands.remove(node.id),
        onRename: () => _rename(node),
      ),
    );
  }

  /// أين يذهب السحب المُفلت على هذا السطر: داخل الحاوية إن قبلت، وإلا قبل
  /// الطبقة كأخت لها. لا يضيء السطر إلا على واحد منهما.
  _DropTarget? _dropTarget({
    required BuilderDrag drag,
    required DesignNode node,
    required DesignNode? parent,
    required int index,
  }) {
    if (parent == null) return null;
    if (drag.existingId == node.id) return null;
    if (rejectionOfDrop(
          document: widget.document,
          page: widget.page,
          drag: drag,
          parentId: node.id,
        ) ==
        DesignEditRejection.none) {
      return _DropTarget(
        parentId: node.id,
        siblings: node.children,
        slotIndex: node.children.length,
      );
    }
    if (rejectionOfDrop(
          document: widget.document,
          page: widget.page,
          drag: drag,
          parentId: parent.id,
        ) ==
        DesignEditRejection.none) {
      return _DropTarget(
        parentId: parent.id,
        siblings: parent.children,
        slotIndex: index,
      );
    }
    return null;
  }

  Future<void> _rename(DesignNode node) async {
    final renamed = await showDialog<String>(
      context: context,
      builder: (context) =>
          _RenameDialog(current: node.id, rejectionLabel: _rejectionLabel),
    );
    if (renamed == null) return;
    final rejection = widget.commands.rename(node.id, renamed);
    if (rejection != DesignEditRejection.none && mounted) {
      _showRejection(rejection);
    }
  }

  void _showRejection(DesignEditRejection rejection) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_rejectionLabel(rejection))),
    );
  }

  static String _rejectionLabel(DesignEditRejection rejection) =>
      S.builderRejection(rejection.name);
}

/// موضع إفلات محسوب: الأب، وإخوته كما هم الآن، والموضع قبل إخراج المنقولة.
class _DropTarget {
  const _DropTarget({
    required this.parentId,
    required this.siblings,
    required this.slotIndex,
  });

  final String parentId;
  final List<DesignNode> siblings;
  final int slotIndex;

  int indexFor(BuilderDrag drag) => dropIndex(
    drag: drag,
    siblings: siblings,
    slotIndex: slotIndex,
  );
}

/// سطر طبقة واحدة: اسمها وحالتها وأوامرها، منزاحة بقدر عمقها في الشجرة.
class _Row extends StatelessWidget {
  const _Row({
    required this.node,
    required this.label,
    required this.depth,
    required this.selected,
    required this.hidden,
    required this.locked,
    required this.draggable,
    required this.hot,
    required this.canFold,
    required this.folded,
    required this.enabled,
    required this.language,
    required this.onSelect,
    required this.onFold,
    required this.onToggleVisible,
    required this.onDuplicate,
    required this.onRemove,
    required this.onRename,
  });

  final DesignNode node;
  final String label;
  final int depth;
  final bool selected;
  final bool hidden;
  final bool locked;
  final bool draggable;

  /// سحب فوق هذا السطر الآن: يُرسم خط قبل السطر حتى لا يُحسب الموضع على غفلة.
  final bool hot;
  final bool canFold;
  final bool folded;
  final bool enabled;
  final AppLanguage language;
  final VoidCallback onSelect;
  final VoidCallback onFold;
  final VoidCallback onToggleVisible;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indent = AppDimensions.builderTreeIndent * depth;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? adminTintedSurfaceColor(theme) : null,
        border: Border(
          top: hot
              ? BorderSide(
                  color: AppColor.adminAccent,
                  width: AppDimensions.builderIndicatorStroke,
                )
              : BorderSide.none,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: indent + AppSpacing.xs,
            end: AppSpacing.xs,
            top: AppSpacing.xxs,
            bottom: AppSpacing.xxs,
          ),
          child: Row(
            children: [
              if (canFold)
                IconButton(
                  onPressed: onFold,
                  visualDensity: VisualDensity.compact,
                  iconSize: AppDimensions.iconSizeSm,
                  icon: Icon(folded ? AppIcons.arrowRight01 : AppIcons.arrowDown01),
                  tooltip: label,
                )
              else
                SizedBox(width: AppSizes.px8 * 3),
              if (draggable)
                Draggable<BuilderDrag>(
                  data: BuilderDrag(type: node.type, existingId: node.id),
                  feedback: BuilderDragFeedback(label: label),
                  child: Icon(
                    AppIcons.menu01,
                    size: AppSizes.px14,
                    color: adminSubtleColor(theme),
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? AppColor.adminAccent
                            : adminHeadingColor(theme),
                        fontSize: AppFontSizes.size10_5,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                    Text(
                      node.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminSubtleColor(theme),
                        fontSize: AppFontSizes.size9,
                        fontWeight: AppFontWeights.regular,
                        height: AppTextHeights.line1_3,
                      ),
                    ),
                  ],
                ),
              ),
              if (hidden)
                Text(
                  S.builderHiddenBadge,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9,
                    fontWeight: AppFontWeights.medium,
                    height: AppTextHeights.line1_3,
                  ),
                ),
              if (locked)
                Text(
                  S.builderLockedBadge,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9,
                    fontWeight: AppFontWeights.medium,
                    height: AppTextHeights.line1_3,
                  ),
                ),
              if (enabled && !locked)
                _Actions(
                  hidden: hidden,
                  onToggleVisible: onToggleVisible,
                  onDuplicate: onDuplicate,
                  onRemove: onRemove,
                  onRename: onRename,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// أوامر السطر: إظهار/إخفاء، تسمية، تكرار، حذف.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.hidden,
    required this.onToggleVisible,
    required this.onDuplicate,
    required this.onRemove,
    required this.onRename,
  });

  final bool hidden;
  final VoidCallback onToggleVisible;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(
          icon: hidden ? AppIcons.eyeOff : AppIcons.eyeIcon,
          tooltip: hidden ? S.builderShow : S.builderHide,
          onPressed: onToggleVisible,
        ),
        _button(
          icon: AppIcons.pencilEdit02,
          tooltip: S.builderRename,
          onPressed: onRename,
        ),
        _button(
          icon: AppIcons.copy01,
          tooltip: S.builderDuplicate,
          onPressed: onDuplicate,
        ),
        _button(
          icon: AppIcons.delete01,
          tooltip: S.delete,
          onPressed: onRemove,
        ),
      ],
    );
  }

  Widget _button({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: AppSizes.px14,
      icon: Icon(icon),
    );
  }
}

/// نافذة إعادة التسمية: تعرض سبب الرفض في مكانها ولا تُغلق على طبقة بلا اسم.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.current, required this.rejectionLabel});

  final String current;
  final String Function(DesignEditRejection rejection) rejectionLabel;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = S.builderRejection('emptyId'));
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.builderRenameTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.builderRenameNote,
            style: TextStyle(
              color: adminMutedColor(Theme.of(context)),
              fontSize: AppFontSizes.size10,
              fontWeight: AppFontWeights.regular,
              height: AppTextHeights.line1_5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: S.builderRenameTitle,
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(S.save)),
      ],
    );
  }
}
