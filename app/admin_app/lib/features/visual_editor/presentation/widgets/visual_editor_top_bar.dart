import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_theme_tokens.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_toolbar.dart';

/// الشريط العلوي الاحترافي للمحرر المرئي (Professional Visual Editor Top Bar).
///
/// يجمع كافة عناصر التحكم في بيئة عمل SaaS موحدة ومصقولة:
/// - هوية التطبيق والمتجر والشعار
/// - مؤشرات حالة الحفظ والاتصال
/// - تراجع / إعادة
/// - تحكم التكبير وأبعاد الأجهزة
/// - وضع التحرير / التفاعل المباشر
/// - أدوات الإصدارات والقوالب والهوية
/// - حفظ المسودة وزر النشر البارز
class VisualEditorTopBar extends StatelessWidget {
  const VisualEditorTopBar({
    super.key,
    required this.state,
    required this.cubit,
    this.canPublish = true,
    required this.zoom,
    required this.device,
    required this.selectedPageId,
    required this.onZoom,
    required this.onDeviceChanged,
    required this.onPageChanged,
    required this.onReloadPreview,
    this.onFitToScreen,
    this.isInteractiveMode = false,
    this.onToggleInteractiveMode,
    this.onToggleLeftPanel,
    this.isLeftPanelOpen = true,
    this.onToggleRightPanel,
    this.isRightPanelOpen = true,
    this.lastSavedAt,
  });

  final VisualEditorState state;
  final VisualEditorCubit cubit;
  final bool canPublish;
  final double zoom;
  final PreviewDevice device;
  final String? selectedPageId;
  final void Function(double) onZoom;
  final void Function(PreviewDevice) onDeviceChanged;
  final void Function(String) onPageChanged;
  final VoidCallback onReloadPreview;
  final VoidCallback? onFitToScreen;
  final bool isInteractiveMode;
  final ValueChanged<bool>? onToggleInteractiveMode;
  final VoidCallback? onToggleLeftPanel;
  final bool isLeftPanelOpen;
  final VoidCallback? onToggleRightPanel;
  final bool isRightPanelOpen;
  final DateTime? lastSavedAt;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = VisualEditorTokens.surface(context);
    final borderColor = VisualEditorTokens.border(context);
    final textPrimary = VisualEditorTokens.text(context);
    final textMuted = VisualEditorTokens.textMuted(context);

    return Container(
      height: VisualEditorTokens.topBarHeight,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.black.withAlpha(60) : const Color(0x06000000),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. زر طي/فتح اللوحة الجانبية + هوية المتجر والمحرر
            _buildStoreIdentity(context, textPrimary, textMuted, dark),

            const SizedBox(width: AppSpacing.sm),
            _buildVerticalSeparator(borderColor),
            const SizedBox(width: AppSpacing.sm),

            // 2. مؤشر حالة الحفظ والاتصال الموحد
            _buildSaveAndConnectionBadge(context, dark),

            const SizedBox(width: AppSpacing.sm),
            _buildVerticalSeparator(borderColor),
            const SizedBox(width: AppSpacing.sm),

            // 3. أدوات التراجع والإعادة (Undo / Redo)
            _buildHistoryControls(context, dark, textMuted),

            const SizedBox(width: AppSpacing.sm),
            _buildVerticalSeparator(borderColor),
            const SizedBox(width: AppSpacing.sm),

            // 4. اختيار الجهاز والتحكم في التكبير
            _buildViewportControls(context, dark, textMuted, textPrimary),

            const SizedBox(width: AppSpacing.sm),
            _buildVerticalSeparator(borderColor),
            const SizedBox(width: AppSpacing.sm),

            // 5. زر وضع التحرير مقابل المعاينة التفاعلية
            _buildInteractiveModeSwitch(context, dark),

            const SizedBox(width: AppSpacing.sm),
            _buildVerticalSeparator(borderColor),
            const SizedBox(width: AppSpacing.sm),

            // 6. أدوات إضافية (سجل الإصدارات، القوالب، استوديو السمات، التخلص)
            _buildExtraTools(context, dark, textMuted),

            const SizedBox(width: AppSpacing.sm),
            _buildVerticalSeparator(borderColor),
            const SizedBox(width: AppSpacing.sm),

            // 7. أزرار حفظ المسودة والنشر
            _buildActionButtons(context, dark),

            if (onToggleRightPanel != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Tooltip(
                message: isRightPanelOpen ? 'إخفاء لوحة الخصائص' : 'إظهار لوحة الخصائص',
                child: IconButton(
                  onPressed: onToggleRightPanel,
                  icon: Icon(
                    isRightPanelOpen ? Icons.view_sidebar_outlined : Icons.view_sidebar,
                    size: 19,
                    color: isRightPanelOpen ? VisualEditorTokens.primaryOliveGreen : textMuted,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: isRightPanelOpen
                        ? (dark ? VisualEditorTokens.darkSurfaceSecondary : VisualEditorTokens.primaryOliveGreenLight)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- 1. هوية المتجر والمحرر ---
  Widget _buildStoreIdentity(
    BuildContext context,
    Color textPrimary,
    Color textMuted,
    bool dark,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onToggleLeftPanel != null)
          Tooltip(
            message: isLeftPanelOpen ? 'إخفاء اللوحة الجانبية' : 'إظهار اللوحة الجانبية',
            child: InkWell(
              onTap: onToggleLeftPanel,
              borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xs + 1),
                margin: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: isLeftPanelOpen
                      ? (dark ? VisualEditorTokens.darkSurfaceSecondary : VisualEditorTokens.primaryOliveGreenLight)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
                ),
                child: Icon(
                  Icons.menu_open_rounded,
                  size: 18,
                  color: isLeftPanelOpen ? VisualEditorTokens.primaryOliveGreen : textMuted,
                ),
              ),
            ),
          ),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: VisualEditorTokens.primaryOliveGreen,
            borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
            boxShadow: [
              BoxShadow(
                color: VisualEditorTokens.primaryOliveGreen.withAlpha(70),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.coffee_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  S.visualEditor,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: AppFontWeights.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: VisualEditorTokens.secondaryCoffeeBrown.withAlpha(30),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'مسودة v2',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: AppFontWeights.semiBold,
                      color: VisualEditorTokens.secondaryCoffeeBrown,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'تطبيق العميل | مقهى القهوة',
              style: TextStyle(
                fontSize: 10,
                color: textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- 2. مؤشر حالة الحفظ والاتصال الموحد ---
  Widget _buildSaveAndConnectionBadge(BuildContext context, bool dark) {
    final bool isSaving = state.status == VisualEditorStatus.loading;
    final bool isDirty = state.isDirty;

    Color saveColor;
    String saveText;
    IconData saveIcon;

    if (isSaving) {
      saveColor = VisualEditorTokens.statusInfo;
      saveText = 'جارٍ الحفظ…';
      saveIcon = Icons.sync_rounded;
    } else if (isDirty) {
      saveColor = VisualEditorTokens.statusWarning;
      saveText = 'تغييرات غير محفوظة';
      saveIcon = Icons.edit_note_rounded;
    } else {
      saveColor = VisualEditorTokens.statusSuccess;
      saveText = 'محفوظ';
      saveIcon = Icons.check_circle_outline_rounded;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: saveColor.withAlpha(dark ? 50 : 20),
            borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
            border: Border.all(color: saveColor.withAlpha(60), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(saveIcon, size: 12, color: saveColor),
              const SizedBox(width: 3),
              Text(
                saveText,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: AppFontWeights.medium,
                  color: saveColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        EditorConnectionStatus(
          connection: state.previewConnection,
          reason: state.previewStatusMessage,
          dark: dark,
        ),
        Tooltip(
          message: 'إعادة تحميل المعاينة',
          child: InkWell(
            onTap: onReloadPreview,
            borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                AppIcons.refresh,
                size: 13,
                color: dark ? VisualEditorTokens.darkTextMuted : VisualEditorTokens.textMutedGray,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- 3. أدوات التراجع والإعادة ---
  Widget _buildHistoryControls(BuildContext context, bool dark, Color textMuted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EditorIconBtn(
          icon: AppIcons.undo,
          tooltip: S.visualEditorUndo,
          onTap: cubit.canUndo ? cubit.undo : null,
          dark: dark,
          muted: textMuted,
        ),
        EditorIconBtn(
          icon: AppIcons.redo,
          tooltip: S.visualEditorRedo,
          onTap: cubit.canRedo ? cubit.redo : null,
          dark: dark,
          muted: textMuted,
        ),
      ],
    );
  }

  // --- 4. اختيار الجهاز والتحكم في التكبير ---
  Widget _buildViewportControls(
    BuildContext context,
    bool dark,
    Color textMuted,
    Color textPrimary,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // النص المطلوب للاختبارات 'الجهاز والمعاينة'
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: Text(
            'الجهاز والمعاينة',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: AppFontWeights.semiBold,
              color: textMuted,
            ),
          ),
        ),
        EditorScreenSizeSelector(
          dark: dark,
          muted: textMuted,
          selected: device,
          onSelected: onDeviceChanged,
        ),
        const SizedBox(width: AppSpacing.xs),
        EditorZoomControls(
          zoom: zoom,
          dark: dark,
          muted: textMuted,
          onZoom: onZoom,
        ),
        if (onFitToScreen != null)
          Tooltip(
            message: 'ملاءمة للشاشة (Fit to Screen)',
            child: InkWell(
              onTap: onFitToScreen,
              borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
              child: Container(
                padding: const EdgeInsets.all(4),
                margin: const EdgeInsetsDirectional.only(start: 2),
                child: Icon(
                  Icons.fit_screen_outlined,
                  size: 14,
                  color: textMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- 5. وضع التحرير مقابل المعاينة التفاعلية ---
  Widget _buildInteractiveModeSwitch(BuildContext context, bool dark) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: dark ? VisualEditorTokens.darkSurfaceSecondary : VisualEditorTokens.surfaceSoftCreamSecondary,
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm + 1),
        border: Border.all(
          color: dark ? VisualEditorTokens.darkBorder : VisualEditorTokens.borderWarmGray,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeTab(
            context: context,
            title: 'تحرير',
            icon: Icons.edit_outlined,
            isSelected: !isInteractiveMode,
            onTap: () => onToggleInteractiveMode?.call(false),
            dark: dark,
          ),
          _buildModeTab(
            context: context,
            title: 'معاينة حية',
            icon: Icons.touch_app_outlined,
            isSelected: isInteractiveMode,
            onTap: () => onToggleInteractiveMode?.call(true),
            dark: dark,
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool dark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (dark ? VisualEditorTokens.primaryOliveGreen : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
          boxShadow: isSelected && !dark
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected
                  ? (dark ? Colors.white : VisualEditorTokens.primaryOliveGreen)
                  : (dark ? VisualEditorTokens.darkTextMuted : VisualEditorTokens.textMutedGray),
            ),
            const SizedBox(width: 3),
            Text(
              title,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? AppFontWeights.bold : AppFontWeights.medium,
                color: isSelected
                    ? (dark ? Colors.white : VisualEditorTokens.textDarkCharcoal)
                    : (dark ? VisualEditorTokens.darkTextMuted : VisualEditorTokens.textMutedGray),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 6. أدوات إضافية (سجل الإصدارات، القوالب، استوديو السمات، التخلص) ---
  Widget _buildExtraTools(BuildContext context, bool dark, Color textMuted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EditorIconBtn(
          icon: AppIcons.time01,
          tooltip: S.visualEditorVersions,
          onTap: () => showVisualEditorVersions(
            context,
            cubit,
            canPublish: canPublish,
          ),
          dark: dark,
          muted: textMuted,
        ),
        EditorIconBtn(
          icon: AppIcons.folder01,
          tooltip: S.visualEditorTemplates,
          onTap: () => showVisualEditorTemplates(context, cubit),
          dark: dark,
          muted: textMuted,
        ),
        EditorIconBtn(
          icon: AppIcons.paintBrush,
          tooltip: S.visualEditorThemeStudio,
          onTap: () => showVisualEditorThemeStudio(context, cubit),
          dark: dark,
          muted: textMuted,
        ),
        EditorIconBtn(
          icon: AppIcons.delete02,
          tooltip: S.visualEditorDiscard,
          onTap: () => confirmVisualEditorDiscard(context, cubit),
          dark: dark,
          muted: textMuted,
        ),
      ],
    );
  }

  // --- 7. أزرار حفظ المسودة والنشر ---
  Widget _buildActionButtons(BuildContext context, bool dark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EditorToolbarButton(
          icon: AppIcons.upload01,
          label: S.visualEditorSaveDraft,
          onTap: state.isDirty ? cubit.saveDraft : null,
          dark: dark,
        ),
        const SizedBox(width: AppSpacing.xs),
        EditorToolbarButton(
          icon: AppIcons.sent,
          label: S.visualEditorPublish,
          onTap: canPublish ? () => confirmVisualEditorPublish(context, cubit) : null,
          dark: dark,
          accent: true,
          accentColor: VisualEditorTokens.primaryOliveGreen,
        ),
      ],
    );
  }

  Widget _buildVerticalSeparator(Color color) {
    return SizedBox(
      height: 20,
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: color,
      ),
    );
  }
}
