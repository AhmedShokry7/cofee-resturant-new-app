import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/app_builder_cubit.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/app_builder_state.dart';
import 'package:admin_app/shared/widgets/admin_segmented_control.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

/// شريط المحرّر: صفحة، ووضع، ومصدر، وخطوات، وحفظ ونشر، ومقياس اللوحة.
///
/// كل زر هنا يفعله المحرّر وحده — لا كتابة شجرة في الواجهة. والزرّ الذي لا
/// يعمل يُطبع مطفأً مع سببه في تلميح، لأن زرًّا يبدو صالحًا ثم يرفض أصعب على
/// الموظف من زرّ ميت من أول نظرة.
class BuilderToolbar extends StatelessWidget {
  const BuilderToolbar({
    super.key,
    required this.state,
    required this.cubit,
    required this.zoom,
    required this.onZoom,
    required this.canEdit,
    required this.canPublish,
  });

  final AppBuilderState state;
  final AppBuilderCubit cubit;

  /// مقياس اللوحة: تحت 1 تصغر لتسع الشاشة، وفوقه تكبر لتقرأ ما ضاقت عنه.
  final double zoom;
  final ValueChanged<double> onZoom;

  /// صلاحيات القاعدة كما قرأتهما الجلسة: التحرير وحده يفتح الحفظ، والنشر وحده
  /// يفتح النشر والرجوع. الإطفاء هنا راحة للموظف، والحماية في القاعدة.
  final bool canEdit;
  final bool canPublish;

  /// التحرير يعمل لمن يملك صلاحيته وعلى صفحة تُحرَّر وفي وضع البناء؛ عداه عرض.
  bool get _canEdit => canEdit && state.page.isEditable && !state.isPreview;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _pagePicker(context),
        AdminSegmentedControl(
          options: <String>[S.builderModeEdit, S.builderModePreview],
          selected: state.isPreview ? S.builderModePreview : S.builderModeEdit,
          onChanged: (option) => cubit.setMode(
            option == S.builderModePreview
                ? AppBuilderMode.preview
                : AppBuilderMode.edit,
          ),
        ),
        _sourcePicker(context),
        _actions(context),
        _zoom(context),
        _DirtyBadge(dirty: state.isDirty),
      ],
    );
  }

  // ---------- الصفحة ----------

  Widget _pagePicker(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: adminControlBorderColor(theme)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppPage>(
          value: state.page,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          items: <DropdownMenuItem<AppPage>>[
            for (final page in AppPage.values)
              DropdownMenuItem(
                value: page,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      page.isEditable
                          ? AppIcons.layers01
                          : AppIcons.securityCheck,
                      size: AppDimensions.iconSizeSm,
                      color: page.isEditable
                          ? adminBodyColor(theme)
                          : adminSubtleColor(theme),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      S.builderPageName(page.key),
                      style: AppFonts.regular14(context),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (page) {
            if (page != null) cubit.openPage(page);
          },
        ),
      ),
    );
  }

  // ---------- المصدر ----------

  Widget _sourcePicker(BuildContext context) {
    final theme = Theme.of(context);
    final hasVersions = state.versions.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: adminControlBorderColor(theme)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppBuilderSource>(
          value: state.source,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          items: <DropdownMenuItem<AppBuilderSource>>[
            for (final source in AppBuilderSource.values)
              if (source != AppBuilderSource.version || hasVersions)
                DropdownMenuItem(
                  value: source,
                  child: Text(
                    _sourceLabel(source),
                    style: AppFonts.regular14(context),
                  ),
                ),
          ],
          onChanged: (source) {
            if (source != null) cubit.showSource(source);
          },
        ),
      ),
    );
  }

  String _sourceLabel(AppBuilderSource source) => switch (source) {
    AppBuilderSource.draft => S.builderSourceDraft,
    AppBuilderSource.published => S.builderSourcePublished,
    AppBuilderSource.version => S.builderSourceVersion,
  };

  // ---------- الخطوات والحفظ ----------

  Widget _actions(BuildContext context) {
    // مانعان مختلفان، ورسالتان مختلفتان: من يظن أن الشجرة هي العيب يضيع وقتًا
    // على مانع لا يملكه أصلًا.
    final publishBlocked = !canPublish || !_canEdit || !state.canPublish;
    final publishHint = !canPublish
        ? S.builderPublishNeedsPermission
        : !state.canPublish
        ? S.builderPublishBlocked
        : !_canEdit
        ? S.builderPublishNeedsEdit
        : S.builderPublish;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        AdminToolbarButton(
          label: S.builderUndo,
          icon: AppIcons.undo,
          onPressed: state.canUndo ? cubit.undo : null,
        ),
        AdminToolbarButton(
          label: S.builderRedo,
          icon: AppIcons.redo,
          onPressed: state.canRedo ? cubit.redo : null,
        ),
        AdminToolbarButton(
          label: state.isSaving ? S.builderSaving : S.builderSave,
          icon: AppIcons.taskDone01,
          busy: state.isSaving,
          onPressed: _canEdit && state.isDirty ? cubit.saveDraft : null,
        ),
        Tooltip(
          message: publishHint,
          child: AdminToolbarButton(
            label: state.isPublishing ? S.builderPublishing : S.builderPublish,
            icon: AppIcons.upload01,
            busy: state.isPublishing,
            active: !publishBlocked,
            onPressed: publishBlocked ? null : cubit.publish,
          ),
        ),
        AdminToolbarButton(
          label: S.builderDiscard,
          icon: AppIcons.refresh,
          onPressed: _canEdit && state.isDirty ? cubit.discardDraft : null,
        ),
      ],
    );
  }

  // ---------- المقياس ----------

  Widget _zoom(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: adminControlBorderColor(theme)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: S.builderZoomOut,
            onPressed: zoom > AppDimensions.builderZoomMin + .001
                ? () => onZoom(zoom - AppDimensions.builderZoomStep)
                : null,
            icon: Icon(AppIcons.zoomOutArea, size: AppDimensions.iconSizeSm),
          ),
          Text(
            '${(zoom * 100).round()}%',
            style: TextStyle(
              color: adminBodyColor(theme),
              fontSize: AppFontSizes.size11,
              fontWeight: AppFontWeights.semiBold,
            ),
          ),
          IconButton(
            tooltip: S.builderZoomIn,
            onPressed: zoom < AppDimensions.builderZoomMax - .001
                ? () => onZoom(zoom + AppDimensions.builderZoomStep)
                : null,
            icon: Icon(AppIcons.zoomInArea, size: AppDimensions.iconSizeSm),
          ),
          IconButton(
            tooltip: S.builderZoomReset,
            onPressed: zoom == AppDimensions.builderZoomDefault
                ? null
                : () => onZoom(AppDimensions.builderZoomDefault),
            icon: Icon(AppIcons.refresh, size: AppDimensions.iconSizeSm),
          ),
        ],
      ),
    );
  }
}

/// هل في اللوحة ما لم يصل القاعدة؟ تُطبع الحالة، ولا يُترك الموظف يخمّن.
class _DirtyBadge extends StatelessWidget {
  const _DirtyBadge({required this.dirty});

  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = dirty ? AppColor.adminWarning : adminSubtleColor(theme);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: dirty ? AppColor.adminWarningSurface : Colors.transparent,
        border: Border.all(color: dirty ? color : adminRowBorderColor(theme)),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        dirty ? S.builderDirty : S.builderClean,
        style: TextStyle(
          color: color,
          fontSize: AppFontSizes.size10,
          fontWeight: AppFontWeights.semiBold,
        ),
      ),
    );
  }
}
