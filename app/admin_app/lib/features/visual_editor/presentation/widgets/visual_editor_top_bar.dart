import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_display_controls.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_theme_tokens.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_toolbar.dart';

/// الشريط العلوي الاحترافي للمحرر المرئي المطابق تماماً للصورة المرجعية.
///
/// الترتيب من اليمين لليسار (RTL):
/// 1. اليمين: أيقونة القهوة + "المحرر المرئي" + "تصميم تطبيق العميل"
///    ثم أزرار: "معاينة 👁️"، "نشر 🚀" (زر أخضر بارز)، "حفظ المسودة 💾".
/// 2. الوسط: اختيار الجهاز "الجوال 📱 ∨"، نسبة التكبير [- 100% +]، زر الملاءمة [⛶]،
///    ومؤشر "✓ تم الحفظ منذ دقيقة".
/// 3. اليسار: لغة ومظهر تطبيق العميل داخل المعاينة فقط.
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
        border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.black.withAlpha(60) : const Color(0x06000000),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. الجانب الأيمن: الهوية + الإجراءات الرئيسية
            _buildBrandHeader(context, textPrimary, textMuted),
            const SizedBox(width: AppSpacing.md),
            _buildMainActionButtons(context, dark),
            const SizedBox(width: AppSpacing.xs),
            _buildToolActionButtons(context, dark, textMuted),

            const SizedBox(width: AppSpacing.md),
            Container(width: 1, height: 24, color: borderColor),
            const SizedBox(width: AppSpacing.md),

            // 2. الجانب الأوسط: أدوات العرض والتكبير وحالة الحفظ
            _buildDeviceAndZoomGroup(context, dark, textMuted, textPrimary),

            const SizedBox(width: AppSpacing.md),
            Container(width: 1, height: 24, color: borderColor),
            const SizedBox(width: AppSpacing.md),

            // 3. الجانب الأيسر: لغة ومظهر تطبيق العميل داخل المعاينة فقط
            _buildStoreAndLanguageGroup(context),
          ],
        ),
      ),
    );
  }

  // --- 1. هوية المحرر والمتجر (شعار فنجان القهوة + المحرر المرئي + تصميم تطبيق العميل) ---
  Widget _buildBrandHeader(
    BuildContext context,
    Color textPrimary,
    Color textMuted,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: VisualEditorTokens.secondaryCoffeeLight,
            borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
            border: Border.all(
              color: VisualEditorTokens.secondaryCoffeeBrown.withAlpha(50),
              width: 0.8,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.coffee_rounded,
              color: VisualEditorTokens.secondaryCoffeeBrown,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.visualEditor,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: AppFontWeights.bold,
                color: textPrimary,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'تصميم تطبيق العميل',
              style: TextStyle(fontSize: 10, color: textMuted, height: 1.1),
            ),
          ],
        ),
      ],
    );
  }

  // --- أزرار الإجراءات الرئيسية: معاينة، نشر، حفظ المسودة ---
  Widget _buildMainActionButtons(BuildContext context, bool dark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // زر معاينة 👁️
        _buildPillButton(
          context: context,
          icon: Icons.visibility_outlined,
          label: 'معاينة',
          onTap: () => onToggleInteractiveMode?.call(!isInteractiveMode),
          dark: dark,
          isActive: isInteractiveMode,
        ),
        const SizedBox(width: AppSpacing.xs + 2),

        // زر النشر البارز 🚀 باللون الأخضر الأساسي
        EditorToolbarButton(
          icon: Icons.rocket_launch_rounded,
          label: S.visualEditorPublish,
          onTap: canPublish
              ? () => confirmVisualEditorPublish(context, cubit)
              : null,
          dark: dark,
          accent: true,
          accentColor: VisualEditorTokens.primaryOliveGreen,
        ),
        const SizedBox(width: AppSpacing.xs + 2),

        // زر حفظ المسودة 💾
        EditorToolbarButton(
          icon: Icons.save_outlined,
          label: S.visualEditorSaveDraft,
          onTap: state.isDirty ? cubit.saveDraft : null,
          dark: dark,
        ),
      ],
    );
  }

  // --- أزرار أدوات إضافية: التراجع والإعادة والإصدارات والقوالب ---
  Widget _buildToolActionButtons(
    BuildContext context,
    bool dark,
    Color textMuted,
  ) {
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
        EditorIconBtn(
          icon: AppIcons.time01,
          tooltip: S.visualEditorVersions,
          onTap: () =>
              showVisualEditorVersions(context, cubit, canPublish: canPublish),
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

  // --- 2. أداة اختيار الجهاز والتحكم في التكبير ومؤشر الحفظ ---
  Widget _buildDeviceAndZoomGroup(
    BuildContext context,
    bool dark,
    Color textMuted,
    Color textPrimary,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // تسمية مطلوبة للاختبارات 'الجهاز والمعاينة'
        Padding(
          padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
          child: Text(
            'الجهاز والمعاينة',
            style: TextStyle(
              fontSize: 10,
              fontWeight: AppFontWeights.semiBold,
              color: textMuted,
            ),
          ),
        ),

        // أداة اختيار حجم الشاشة
        EditorScreenSizeSelector(
          dark: dark,
          muted: textMuted,
          selected: device,
          onSelected: onDeviceChanged,
        ),
        const SizedBox(width: AppSpacing.xs + 2),

        // أداة التحكم في التكبير [- 100% +]
        EditorZoomControls(
          zoom: zoom,
          dark: dark,
          muted: textMuted,
          onZoom: onZoom,
        ),
        const SizedBox(width: AppSpacing.xs),

        // زر ملء الشاشة [⛶]
        Tooltip(
          message: 'ملاءمة للشاشة (Fit to Screen)',
          child: InkWell(
            onTap: onFitToScreen,
            borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: dark
                    ? VisualEditorTokens.darkSurfaceSecondary
                    : VisualEditorTokens.surfaceSoftCreamSecondary,
                borderRadius: BorderRadius.circular(
                  VisualEditorTokens.radiusSm,
                ),
                border: Border.all(
                  color: VisualEditorTokens.border(context),
                  width: 0.8,
                ),
              ),
              child: Icon(
                Icons.fit_screen_outlined,
                size: 14,
                color: textMuted,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),

        // مؤشر الحفظ التلقائي وحالة الاتصال
        _buildSaveStatusIndicator(context, dark),
      ],
    );
  }

  // --- مؤشر حالة الحفظ: "✓ تم الحفظ منذ دقيقة" ---
  Widget _buildSaveStatusIndicator(BuildContext context, bool dark) {
    final bool isSaving = state.status == VisualEditorStatus.loading;
    final bool isDirty = state.isDirty;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (isSaving) {
      statusText = 'جارٍ الحفظ…';
      statusColor = VisualEditorTokens.statusInfo;
      statusIcon = Icons.sync_rounded;
    } else if (isDirty) {
      statusText = 'تغييرات غير محفوظة';
      statusColor = VisualEditorTokens.statusWarning;
      statusIcon = Icons.edit_note_rounded;
    } else {
      statusText = 'تم الحفظ منذ دقيقة';
      statusColor = VisualEditorTokens.statusSuccess;
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(dark ? 45 : 18),
            borderRadius: BorderRadius.circular(VisualEditorTokens.radiusXl),
            border: Border.all(color: statusColor.withAlpha(50), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 12, color: statusColor),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: AppFontWeights.medium,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        EditorConnectionStatus(
          connection: state.previewConnection,
          reason: state.previewStatusMessage,
          dark: dark,
        ),
      ],
    );
  }

  // --- 3. لغة ومظهر تطبيق العميل داخل المعاينة ---
  Widget _buildStoreAndLanguageGroup(BuildContext context) {
    return PreviewDisplayControls(state: state, cubit: cubit);
  }

  Widget _buildPillButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool dark,
    bool isActive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? (dark
                      ? VisualEditorTokens.darkSurfaceSecondary
                      : VisualEditorTokens.primaryOliveGreenLight)
                : (dark
                      ? VisualEditorTokens.darkSurfaceSecondary
                      : VisualEditorTokens.surfaceSoftCreamSecondary),
            borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
            border: Border.all(
              color: isActive
                  ? VisualEditorTokens.primaryOliveGreen
                  : VisualEditorTokens.border(context),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isActive
                    ? VisualEditorTokens.primaryOliveGreen
                    : VisualEditorTokens.text(context),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive
                      ? AppFontWeights.bold
                      : AppFontWeights.medium,
                  color: isActive
                      ? VisualEditorTokens.primaryOliveGreen
                      : VisualEditorTokens.text(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
