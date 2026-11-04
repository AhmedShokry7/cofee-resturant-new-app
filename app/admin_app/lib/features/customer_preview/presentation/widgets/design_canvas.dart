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
import 'package:admin_app/features/customer_preview/domain/services/design_tree.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/builder_drag.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/builder_drag_feedback.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/design_renderer.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// إفلات طبقة: [parentId] أبوها، و[index] موضعها في قائمة أبنائه بعد إخراج
/// الطبقة المنقولة — وهو الحساب نفسه الذي تُرسم عليه المؤشرات.
typedef DesignDropHandler =
    void Function(BuilderDrag drag, String parentId, int index);

/// لوحة التحرير: صفحة من المستند تُرسم بأدوية الزبون الحقيقية نفسها، وفوقها
/// حدود التحديد ومواضع الإفلات.
///
/// الرسم واحد في الحالتين: ما تراه اللوحة هو ما يراه الهاتف، والفرق في التفاف
/// كل عقدة بحدودها لا في نسخة ثانية من الشاشة. لذلك تُعرض الطبقات المخفية هنا
/// مع علامة «مخفي»، وهي لا تصل إلى شاشة الزبون.
class DesignCanvas extends StatelessWidget {
  const DesignCanvas({
    super.key,
    required this.document,
    required this.page,
    required this.root,
    required this.scope,
    required this.selectedId,
    required this.onSelect,
    required this.onDrop,
  });

  final DesignDocument document;
  final AppPage page;

  /// جذر الصفحة المحرَّرة، وهو وحده ما تُرسم طبقاته.
  final DesignNode root;

  final DesignRenderScope scope;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final DesignDropHandler onDrop;

  AppLanguage get _panelLanguage => AppLocale.instance.language;

  @override
  Widget build(BuildContext context) {
    // الضغط خارج أي طبقة يترك التحديد: لا تُحرَّر طبقة لأن أحدها ظنّ ما حوله
    // فارغًا.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => onSelect(null),
      child: DesignRenderer(
        node: root,
        scope: scope,
        decorate: _decorate,
        sectionSlot: _slot,
      ),
    );
  }

  // ---------- الطبقات ----------

  Widget _decorate(BuildContext context, DesignNode node, Widget child) {
    // الجذر صفحة لا طبقة: لا يُحدَّد ولا يُنقل، ومواضع إفلاته هي [_slot].
    if (node.id == root.id) return child;
    final spec = WidgetRegistry.of(node.type);
    final locked = DesignTree.isLocked(node.type);
    Widget body = child;
    if (spec != null && spec.canHaveChildren) {
      body = _dropInside(context, node, body);
    }
    return _LayerShell(
      key: ValueKey('layer-${node.id}'),
      label: spec?.name.of(_panelLanguage) ?? node.type,
      selected: node.id == selectedId,
      hidden: !node.isVisible,
      locked: locked,
      onSelect: locked ? null : () => onSelect(node.id),
      // المقبض وحده يُسحب: الطبقة كلها سطح ضغط للتحديد، فلو أخذ السحب كل نقطة
      // لمس عليها لما استطاع أحد أن يحدّ طبقة.
      onDrag: locked
          ? null
          : BuilderDrag(type: node.type, existingId: node.id),
      child: body,
    );
  }

  /// الإفلات داخل حاوية: يُضاف العنصر آخر أبنائها، والترتيب الدقيق يُسحب عليه
  /// بعد ذلك من موضعه.
  Widget _dropInside(BuildContext context, DesignNode node, Widget child) {
    return DragTarget<BuilderDrag>(
      onWillAcceptWithDetails: (details) =>
          rejectionOfDrop(
            document: document,
            page: page,
            drag: details.data,
            parentId: node.id,
          ) ==
          DesignEditRejection.none,
      onAcceptWithDetails: (details) => onDrop(
        details.data,
        node.id,
        dropIndex(
          drag: details.data,
          siblings: node.children,
          slotIndex: node.children.length,
        ),
      ),
      builder: (context, candidates, _) => DecoratedBox(
        decoration: BoxDecoration(
          border: candidates.isEmpty
              ? null
              : Border.all(
                  color: AppColor.adminAccent,
                  width: AppDimensions.builderIndicatorStroke,
                ),
          borderRadius: BorderRadius.circular(
            AppDimensions.builderSelectionRadius,
          ),
        ),
        child: child,
      ),
    );
  }

  // ---------- مواضع الإفلات ----------

  Widget _slot(BuildContext context, DesignNode parent, int index) {
    final siblings = parent.children;
    return DragTarget<BuilderDrag>(
      key: ValueKey('slot-${parent.id}-$index'),
      onWillAcceptWithDetails: (details) =>
          rejectionOfDrop(
            document: document,
            page: page,
            drag: details.data,
            parentId: parent.id,
          ) ==
          DesignEditRejection.none,
      onAcceptWithDetails: (details) => onDrop(
        details.data,
        parent.id,
        dropIndex(drag: details.data, siblings: siblings, slotIndex: index),
      ),
      builder: (context, candidates, _) {
        // قائمة المرشَّحين تحمل عناصر قد تكون null: يُقرأ أولها فقط، فلا تُسمَّى
        // الطبقة الواصفة باسم طبقة مجهولة.
        final drag = candidates.isNotEmpty ? candidates.first : null;
        return _InsertIndicator(
          hot: drag != null,
          label: drag == null
              ? null
              : WidgetRegistry.of(drag.type)?.name.of(_panelLanguage),
        );
      },
    );
  }
}

/// حدود التحديد وتسمية الطبقة ومقبض سحبها وعلامة إخفائها: ما يراه الموظف وحده،
/// لا ما يراه الزبون.
class _LayerShell extends StatelessWidget {
  const _LayerShell({
    super.key,
    required this.label,
    required this.selected,
    required this.hidden,
    required this.locked,
    required this.child,
    this.onSelect,
    this.onDrag,
  });

  final String label;
  final bool selected;
  final bool hidden;

  /// مكوّن أساس: لا تحديد ولا سحب، والرسم وحده في مكانه.
  final bool locked;
  final Widget child;
  final VoidCallback? onSelect;

  /// بيانات السحب حين تُنقل هذه الطبقة، وnull حين لا تُنقل.
  final BuilderDrag? onDrag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSelect,
      child: Opacity(
        opacity: hidden ? AppDimensions.builderHiddenOpacity : 1,
        child: child,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: selected
              ? AppColor.adminAccent
              : hidden || locked
              ? adminCardBorderColor(theme)
              : Colors.transparent,
          width: selected
              ? AppDimensions.builderIndicatorStroke
              : AppSizes.px1,
        ),
        borderRadius: BorderRadius.circular(
          AppDimensions.builderSelectionRadius,
        ),
      ),
      child: Stack(
        children: [
          body,
          if (onDrag != null)
            PositionedDirectional(
              top: AppSpacing.xxs,
              start: AppSpacing.xxs,
              child: Draggable<BuilderDrag>(
                data: onDrag!,
                feedback: BuilderDragFeedback(label: label),
                child: Icon(
                  AppIcons.menu01,
                  size: AppDimensions.iconSizeSm,
                  color: adminMutedColor(theme),
                ),
              ),
            ),
          if (hidden)
            PositionedDirectional(
              top: AppSpacing.xxs,
              end: AppSpacing.xxs,
              child: _LayerBadge(text: S.builderHiddenBadge),
            ),
          if (selected)
            PositionedDirectional(
              bottom: AppSpacing.xxs,
              end: AppSpacing.xxs,
              child: _LayerBadge(text: label, strong: true),
            ),
        ],
      ),
    );
  }
}

/// شارة فوق الطبقة: «مخفي» أو اسم العنصر المحدَّد.
class _LayerBadge extends StatelessWidget {
  const _LayerBadge({required this.text, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: strong ? AppColor.adminAccent : adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: strong ? AppColor.whiteColor : adminMutedColor(theme),
          fontSize: AppFontSizes.size9,
          fontWeight: AppFontWeights.semiBold,
          height: AppTextHeights.line1_3,
        ),
      ),
    );
  }
}

/// مؤشر الإفلات بين مقطعين: خط رفيع هادئ يصير خُطَّافًا بلون الإضافة حين يدخله
/// سحب صالح، ولا يضيء أبدًا على إفلات سيرفضه السجل.
class _InsertIndicator extends StatelessWidget {
  const _InsertIndicator({required this.hot, this.label});

  final bool hot;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: AppDimensions.builderDropSlotHeight,
      child: Center(
        child: hot
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: AppDimensions.builderDropSlotHeight,
                    height: AppDimensions.builderIndicatorStroke,
                    color: AppColor.adminAccent,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  if (label != null) _LayerBadge(text: label!, strong: true),
                ],
              )
            : Container(
                height: AppSizes.px1,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                color: adminRowBorderColor(theme),
              ),
      ),
    );
  }
}
