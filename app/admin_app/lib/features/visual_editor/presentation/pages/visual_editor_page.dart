import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/component_library_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/component_tree_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/properties_inspector_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

/// صفحة المحرر المرئي — نقطة الدخول الوحيدة للميزة.
///
/// تُنشئ [VisualEditorCubit] وتُهيئه، وتبني التخطيط المناسب للعرض:
/// - عريض/متوسط: ثلاثة أعمدة — يمين (العنوان + الصفحات + المكتبة)،
///   منتصف (المعاينة كاملة)، يسار (أدوات الجهاز + الطبقات/الخصائص).
/// - ضيق: كل لوحة تحت الأخرى.
class VisualEditorPage extends StatefulWidget {
  const VisualEditorPage({super.key, this.cubit});

  /// حقن اختياري للاختبارات؛ الإنتاج يبني الـ cubit الافتراضي نفسه.
  final VisualEditorCubit? cubit;

  @override
  State<VisualEditorPage> createState() => _VisualEditorPageState();
}

class _VisualEditorPageState extends State<VisualEditorPage> {
  late final VisualEditorCubit _cubit;
  double _zoom = 1.0;
  PreviewDevice _device = PreviewDevice.phone;
  String _selectedPageId = 'home';

  /// إعادة تحميل المعاينة: يرتفع بمقدار واحد كل ضغطة على زر Reload —
  /// لوحة المعاينة تلتقط التغيّر وتعيد تحميل الإطار دون فقدان المسودة.
  int _previewReloadToken = 0;

  @override
  void initState() {
    super.initState();
    _cubit = widget.cubit ?? VisualEditorCubit();
    _cubit.initialize();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VisualEditorCubit>.value(
      value: _cubit,
      child: BlocBuilder<VisualEditorCubit, VisualEditorState>(
        builder: (context, state) => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pageHorizontalPadding,
            vertical: AppDimensions.pageVerticalPadding,
          ),
          child: _buildBody(context, state),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, VisualEditorState state) {
    if (state.status == VisualEditorStatus.loading) {
      return const AdminLoadingView();
    }
    if (state.status == VisualEditorStatus.failure) {
      return AdminFailureView(
        message: state.errorMessage,
        onRetry: _cubit.initialize,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w >= 1400) return _buildWideLayout(context, state);
        if (w >= 900) return _buildMediumLayout(context, state);
        return _buildNarrowLayout(context, state);
      },
    );
  }

  // ------------------------------------------------------------------ layouts

  /// العرض الواسع والمتوسط: ثلاثة أعمدة. في RTL العمود الأول على اليمين:
  /// العنوان + الصفحات + المكتبة، ثم المعاينة، ثم أدوات الجهاز +
  /// الطبقات/الخصائص. اللوحات الجانبية بعرض ثابت محدود حتى لا تستهلك
  /// مساحة المعاينة مهما اتسعت النافذة.
  Widget _buildWideLayout(BuildContext context, VisualEditorState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 280, child: _pagesSidePanel(context, state)),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: _previewSection(context, state)),
        const SizedBox(width: AppSpacing.lg),
        SizedBox(width: 270, child: _toolsSidePanel(context, state)),
      ],
    );
  }

  Widget _buildMediumLayout(BuildContext context, VisualEditorState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 235, child: _pagesSidePanel(context, state)),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: _previewSection(context, state)),
        const SizedBox(width: AppSpacing.lg),
        SizedBox(width: 225, child: _toolsSidePanel(context, state)),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, VisualEditorState state) {
    // الشاشات الضيقة: المعاينة أولًا بارتفاع كامل، ثم الصفحات ثم الأدوات
    // ثم بقية اللوحات — كل الأدوات موجودة، لا شيء يُحذف.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageTabs(
            selectedPageId: _selectedPageId,
            onChanged: (pageId) {
              setState(() => _selectedPageId = pageId);
              _cubit.loadPage(pageId);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(height: 620, child: _previewSection(context, state)),
          const SizedBox(height: AppSpacing.lg),
          VisualEditorToolbar(
            state: state,
            cubit: _cubit,
            zoom: _zoom,
            device: _device,
            selectedPageId: _selectedPageId,
            onZoom: (v) => setState(() => _zoom = v.clamp(0.5, 2.0)),
            onDeviceChanged: (device) => setState(() => _device = device),
            onPageChanged: (pageId) {
              setState(() => _selectedPageId = pageId);
              _cubit.loadPage(pageId);
            },
            onReloadPreview: () => setState(() => _previewReloadToken++),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(height: 400, child: _componentTreePanel(context, state)),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(height: 400, child: _componentLibrary(context, state)),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(height: 400, child: _propertiesPanel(context, state)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ side panels

  /// بطاقة جانبية موحّدة: نفس لون خلفية اللوحة، بلا هوية جديدة.
  Widget _sideCard(BuildContext context, Widget child) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColor.darkSurfaceContainer : AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.greyColor,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: child,
    );
  }

  /// عنوان صغير لقسم داخل لوحة جانبية.
  Widget _panelLabel(BuildContext context, String label) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: AppFontWeights.semiBold,
          letterSpacing: 0.4,
          color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ panels

  /// الجانب الأيمن (RTL): عنوان المحرر، صفحات تطبيق العميل، ثم مكتبة
  /// المكوّنات — كل ما يخص تنظيم الصفحة وبناء محتواها.
  Widget _pagesSidePanel(BuildContext context, VisualEditorState state) {
    return _sideCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.visualEditor,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: AppFontWeights.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColor.darkText
                      : AppColor.adminHeading,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            S.visualEditorHint,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColor.darkTextSecondary
                  : AppColor.adminMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          EditorDivider(),
          const SizedBox(height: AppSpacing.sm),
          _panelLabel(context, 'صفحات تطبيق العميل'),
          Expanded(
            flex: 5,
            child: _PageList(
              selectedPageId: _selectedPageId,
              onChanged: (pageId) {
                setState(() => _selectedPageId = pageId);
                _cubit.loadPage(pageId);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          EditorDivider(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            flex: 4,
            child: _componentLibrary(context, state),
          ),
        ],
      ),
    );
  }

  /// الجانب الأيسر (RTL): أدوات الجهاز والمعاينة والاتصال وتراجع/إعادة
  /// والإصدارات والقوالب والاستوديو والتخلص والحفظ والنشر، ثم الطبقات
  /// والخصائص — كل ما كان في الشريط العلوي ولم يُحذف منه شيء.
  Widget _toolsSidePanel(BuildContext context, VisualEditorState state) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    final accent = dark ? AppColor.secondaryColor : AppColor.adminAccent;
    return _sideCard(
      context,
      DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _panelLabel(context, 'الجهاز والمعاينة'),
            EditorScreenSizeSelector(
              dark: dark,
              muted: muted,
              selected: _device,
              onSelected: (device) => setState(() => _device = device),
            ),
            const SizedBox(height: AppSpacing.sm),
            EditorZoomControls(
              zoom: _zoom,
              dark: dark,
              muted: muted,
              onZoom: (v) => setState(() => _zoom = v.clamp(0.5, 2.0)),
            ),
            const SizedBox(height: AppSpacing.sm),
            // حالة الاتصال وإعادة التحميل في صف واحد مضغوط.
            Row(
              children: [
                Expanded(
                  child: EditorConnectionStatus(
                    connection: state.previewConnection,
                    reason: state.previewStatusMessage,
                    dark: dark,
                  ),
                ),
                EditorIconBtn(
                  icon: AppIcons.refresh,
                  tooltip: 'إعادة تحميل المعاينة'
                      '${state.previewStatusMessage == null ? '' : ' — ${state.previewStatusMessage}'}',
                  onTap: () => setState(() => _previewReloadToken++),
                  dark: dark,
                  muted: muted,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            EditorDivider(),
            const SizedBox(height: AppSpacing.sm),
            // تراجع وإعادة + سجل الإصدارات والقوالب والاستوديو والتخلص.
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                EditorIconBtn(
                  icon: AppIcons.undo,
                  tooltip: S.visualEditorUndo,
                  onTap: _cubit.canUndo ? _cubit.undo : null,
                  dark: dark,
                  muted: muted,
                ),
                EditorIconBtn(
                  icon: AppIcons.redo,
                  tooltip: S.visualEditorRedo,
                  onTap: _cubit.canRedo ? _cubit.redo : null,
                  dark: dark,
                  muted: muted,
                ),
                EditorIconBtn(
                  icon: AppIcons.time01,
                  tooltip: S.visualEditorVersions,
                  onTap: () => showVisualEditorVersions(context, _cubit),
                  dark: dark,
                  muted: muted,
                ),
                EditorIconBtn(
                  icon: AppIcons.folder01,
                  tooltip: S.visualEditorTemplates,
                  onTap: () => showVisualEditorTemplates(context),
                  dark: dark,
                  muted: muted,
                ),
                EditorIconBtn(
                  icon: AppIcons.paintBrush,
                  tooltip: S.visualEditorThemeStudio,
                  onTap: () => showVisualEditorThemeStudio(context, _cubit),
                  dark: dark,
                  muted: muted,
                ),
                EditorIconBtn(
                  icon: AppIcons.delete02,
                  tooltip: S.visualEditorDiscard,
                  onTap: () => confirmVisualEditorDiscard(context, _cubit),
                  dark: dark,
                  muted: muted,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // حفظ ونشر بأزرار بعرض العمود.
            EditorToolbarButton(
              icon: AppIcons.upload01,
              label: S.visualEditorSaveDraft,
              onTap: state.isDirty ? _cubit.saveDraft : null,
              dark: dark,
            ),
            const SizedBox(height: AppSpacing.sm),
            EditorToolbarButton(
              icon: AppIcons.sent,
              label: S.visualEditorPublish,
              onTap: () => confirmVisualEditorPublish(context, _cubit),
              dark: dark,
              accent: true,
              accentColor: accent,
            ),
            const SizedBox(height: AppSpacing.sm),
            EditorDivider(),
            TabBar(
              isScrollable: false,
              tabs: [
                Tab(
                  icon: const Icon(Icons.layers, size: 16),
                  text: S.visualEditorLayers,
                ),
                Tab(
                  icon: Icon(AppIcons.tune, size: 16),
                  text: S.visualEditorProperties,
                ),
              ],
              labelStyle: const TextStyle(fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _componentTreePanel(context, state),
                  _propertiesPanel(context, state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewSection(BuildContext context, VisualEditorState state) {
    // المنطقة الوسطى للمعاينة حصريًا: بلا شريط صفحات فوقها — الصفحات
    // في اللوحة اليمنى، والمعاينة تملأ كل المساحة المتبقية.
    return PreviewPanel(
      pageId: _selectedPageId,
      zoom: _zoom,
      device: _device,
      sessionId: state.sessionId,
      components: state.getComponentsForPage(_selectedPageId),
      theme: _cubit.theme,
      selectedComponentId: state.selectedComponentId,
      reloadToken: _previewReloadToken,
      onConnectionChanged: (connection, reason) =>
          _cubit.updatePreviewConnection(connection, reason: reason),
      onElementSelected: _cubit.handleElementSelected,
      onPreviewReady: _cubit.handlePreviewReady,
      onPreviewError: _cubit.handlePreviewError,
      onPropertyUpdated: _cubit.handlePropertyUpdated,
      onTreeUpdated: _cubit.handleTreeUpdated,
      outboundMessageType: _cubit.pendingMessage?.type,
      outboundPayload: _cubit.pendingMessage?.payload,
      outboundMessageId: _cubit.pendingMessage?.messageId,
    );
  }

  Widget _componentTreePanel(BuildContext context, VisualEditorState state) {
    return ComponentTreePanel(
      pageId: _selectedPageId,
      components: state.getComponentsForPage(_selectedPageId),
      selectedComponentId: state.selectedComponentId,
      onSelect: _cubit.selectComponent,
      onReorder: _cubit.reorderComponent,
      onDelete: _cubit.deleteComponent,
      onDuplicate: _cubit.duplicateComponent,
      onToggleVisibility: _cubit.toggleComponentVisibility,
    );
  }

  Widget _componentLibrary(BuildContext context, VisualEditorState state) {
    return ComponentLibraryPanel(
      pageId: _selectedPageId,
      availableComponents: ComponentRegistry.getForPage(_selectedPageId),
      onAddComponent: _cubit.addComponent,
    );
  }

  Widget _propertiesPanel(BuildContext context, VisualEditorState state) {
    final selected = state.selectedComponent;
    if (selected == null) {
      return AdminEmptyState(
        icon: AppIcons.tune,
        message: S.visualEditorNoSelection,
        hint: S.visualEditorSelectHint,
      );
    }
    return PropertiesInspectorPanel(
      component: selected,
      onPropertyChanged: _cubit.updateProperty,
      onResetProperty: _cubit.resetProperty,
    );
  }
}

// ---------------------------------------------------------------------- misc

/// قائمة الصفحات العمودية للجانب الأيمن: كل شاشة في تطبيق العميل
/// بالترتيب الذي يراه الزبون، والقفل يعلن أن التحرير للرئيسية والتصنيفات.
class _PageList extends StatelessWidget {
  const _PageList({required this.selectedPageId, required this.onChanged});

  final String selectedPageId;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final page in PreviewPages.all)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ChoiceChip(
                  label: Text(page.label),
                  selected: selectedPageId == page.pageId,
                  onSelected: (_) => onChanged(page.pageId),
                  avatar: page.isEditable
                      ? null
                      : Icon(AppIcons.lock, size: 12),
                  labelStyle: const TextStyle(fontSize: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PageTabs extends StatelessWidget {
  const _PageTabs({required this.selectedPageId, required this.onChanged});

  final String selectedPageId;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // كل شاشات تطبيق العميل بالترتيب: من الافتتاحية إلى آخر شاشة.
          // غير القابلة للتحرير تُفتح للمعاينة أيضًا، وقفلها يعلن أن
          // التحريك متاح للرئيسية والتصنيفات فقط.
          for (final page in PreviewPages.all)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(page.label),
                selected: selectedPageId == page.pageId,
                onSelected: (_) => onChanged(page.pageId),
                avatar: page.isEditable
                    ? null
                    : Icon(AppIcons.lock, size: 12),
                labelStyle: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
