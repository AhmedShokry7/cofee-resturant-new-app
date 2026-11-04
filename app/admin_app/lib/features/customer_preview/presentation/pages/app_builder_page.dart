import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/entities/simulator_tab.dart';
import 'package:admin_app/features/customer_preview/domain/repositories/app_builder_repository.dart';
import 'package:admin_app/features/customer_preview/domain/services/design_tree.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/app_builder_cubit.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/app_builder_state.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/customer_preview_cubit.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/customer_preview_state.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/builder_drag.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/builder_status_panel.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/builder_toolbar.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/customer_preview_rail.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/design_canvas.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/design_renderer.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/phone_frame.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/properties_panel.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_bottom_bar.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_labels.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_status_bar.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_viewport.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/widget_library.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/widget_tree.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// محرّر تطبيق العميل: الهاتف نفسه، وشجرة طبقاته، وخصائص ما يُحدَّد منه.
///
/// الصفحة طريق وحالة حياة فقط: تبني المحرّر ومحاكي البيانات وتقرأهما، وتقرّر
/// عرض الألواح بجانب الهاتف أم تحته. لا شجرة تُعدَّل هنا ولا بيانات تُقرأ —
/// المحرّر يملك المستند، و`CustomerPreviewCubit` يملك الكتالوج والبنرات،
/// والقاعدة تملك آخر كلمة في كل كتابة.
class AppBuilderPage extends StatefulWidget {
  const AppBuilderPage({
    super.key,
    required this.repository,
    this.canEdit = false,
    this.canPublish = false,
    this.cubit,
  });

  /// مصدر الحفظ والنشر: المسودة والإصدارات في القاعدة، لا في ذاكرة اللوحة.
  final AppBuilderRepository repository;

  /// `design.edit` في القاعدة تفتح أدوات الكتابة؛ بغيرها تُعرض الشجرة وتُقرأ ولا
  /// تكتب، والإطفاء هنا راحة لا حماية — القاعدة ترفض كتابته كذلك.
  final bool canEdit;

  /// `design.publish` وحدها تفتح النشر والرجوع إلى إصدار: لوحة من يملك التحرير
  /// وحده ترى سجلّ الإصدارات وتستعرضه، وأزرار النشر معطلة بما يسمّى سببه.
  final bool canPublish;

  /// محرّر جاهز من خارج الصفحة، للاختبار أو لما تبنيه شاشة أعلى.
  final AppBuilderCubit? cubit;

  @override
  State<AppBuilderPage> createState() => _AppBuilderPageState();
}

class _AppBuilderPageState extends State<AppBuilderPage> {
  late final AppBuilderCubit _cubit;
  late final bool _ownsCubit;
  final CustomerPreviewCubit _preview = CustomerPreviewCubit();

  /// مقياس اللوحة: تصغر لتُرى الصفحة كلها، وتكبر ليُقرأ ما ضاقت عنه البطاقة.
  double _zoom = AppDimensions.builderZoomDefault;

  /// الإصدار المعروض داخل الهاتف بعد استعراضه: تعرفه اللوحة وحدها، لأن حالة
  /// المحرّر تملك ملفّ المستند لا رقم صفّه في القاعدة.
  String? _inspectedVersion;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AppBuilderCubit(repository: widget.repository);
    if (_ownsCubit) {
      _cubit.load();
      _preview.load();
    }
  }

  @override
  void dispose() {
    if (_ownsCubit) _cubit.close();
    _preview.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppBuilderCubit>.value(value: _cubit),
        BlocProvider<CustomerPreviewCubit>.value(value: _preview),
      ],
      child: BlocBuilder<AppBuilderCubit, AppBuilderState>(
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.pageHorizontalPadding,
              vertical: AppDimensions.pageVerticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminPageHeader(
                  title: S.appBuilder,
                  // من لا يملك التحرير يقرأ السبب فوق الألواح المطفأة، لا يظن
                  // أن الشجرة فارغة أو أن الزرّ معطوب.
                  subtitle: widget.canEdit
                      ? S.appBuilderHint
                      : S.builderNeedsPermission,
                  footer: BuilderToolbar(
                    state: state,
                    cubit: _cubit,
                    zoom: _zoom,
                    canEdit: widget.canEdit,
                    canPublish: widget.canPublish,
                    onZoom: (next) => setState(
                      () => _zoom = next.clamp(
                        AppDimensions.builderZoomMin,
                        AppDimensions.builderZoomMax,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child:
                      BlocBuilder<CustomerPreviewCubit, CustomerPreviewState>(
                        builder: (context, preview) =>
                            _body(context, state, preview),
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------- الهيكل ----------

  Widget _body(
    BuildContext context,
    AppBuilderState state,
    CustomerPreviewState preview,
  ) {
    if (state.status == AppBuilderStatus.failure) {
      return AdminFailureView(
        message: state.errorMessage,
        onRetry: _cubit.load,
      );
    }
    if (preview.status == CustomerPreviewStatus.failure) {
      return AdminFailureView(
        message: preview.errorMessage,
        onRetry: _preview.load,
      );
    }
    if (state.document == null || preview.feed == null) {
      return const AdminLoadingView();
    }
    final root = state.root;
    if (root == null) {
      // صفحة بلا جذر في المستند: تُقال الحقيقة، ولا تُرسم لوحة على فراغ.
      return AdminEmptyState(
        icon: AppIcons.securityCheck,
        message: S.builderPageLockReason(state.page.lock.name),
      );
    }

    final library = _library(state);
    final tree = _tree(state, root);
    final inspector = _inspector(context, state, preview, root);
    final phone = _phone(context, state, preview, root);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >=
            AppDimensions.builderSideWidth +
                AppDimensions.builderInspectorWidth +
                AppDimensions.simulatorScreenWidth +
                AppSpacing.xl;
        if (!wide) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: phone),
                const SizedBox(height: AppSpacing.lg),
                _card(title: S.builderTree, child: tree),
                const SizedBox(height: AppSpacing.lg),
                _card(title: S.builderLibrary, child: library),
                const SizedBox(height: AppSpacing.lg),
                inspector,
              ],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: AppDimensions.builderSideWidth,
              child: SingleChildScrollView(
                child: _card(title: S.builderLibrary, child: library),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: SingleChildScrollView(child: Center(child: phone)),
            ),
            const SizedBox(width: AppSpacing.lg),
            SizedBox(
              width: AppDimensions.builderInspectorWidth,
              child: SingleChildScrollView(child: inspector),
            ),
          ],
        );
      },
    );
  }

  /// لوح واحد لكل الألواح الجانبية: عنوان القسم ومحتواه، ببطاقة اللوحة نفسها.
  Widget _card({required String title, required Widget child}) {
    return AdminSectionCard(
      title: title,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: child,
    );
  }

  // ---------- الألواح ----------

  bool _writable(AppBuilderState state) =>
      widget.canEdit && state.page.isEditable && !state.isPreview;

  Widget _library(AppBuilderState state) {
    return WidgetLibraryPanel(
      enabled: _writable(state),
      onAdd: (type) => _apply(_cubit.insert(type: type)),
    );
  }

  Widget _tree(AppBuilderState state, DesignNode root) {
    final document = state.document;
    if (document == null) return const SizedBox.shrink();
    return WidgetTreePanel(
      document: document,
      page: state.page,
      root: root,
      selectedId: state.selectedId,
      enabled: _writable(state),
      commands: BuilderCommands(
        select: _cubit.select,
        drop: _drop,
        toggleVisible: (id) => _apply(_cubit.toggleVisible(id)),
        duplicate: (id) => _apply(_cubit.duplicate(id)),
        remove: (id) => _apply(_cubit.remove(id)),
        rename: (id, newId) => _cubit.rename(id: id, newId: newId),
        move: (id, delta) => _move(root, id, delta),
      ),
    );
  }

  Widget _inspector(
    BuildContext context,
    AppBuilderState state,
    CustomerPreviewState preview,
    DesignNode root,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          title: S.builderProperties,
          child: PropertiesPanel(
            node: state.selected,
            page: state.page,
            feed: preview.feed,
            enabled: _writable(state),
            onSet: (id, key, value) =>
                _cubit.setProperty(id: id, key: key, value: value),
            onRejection: _showMessage,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _card(title: S.builderTree, child: _tree(state, root)),
        const SizedBox(height: AppSpacing.lg),
        _card(
          title: S.builderIssues,
          child: BuilderStatusPanel(
            page: state.page,
            validation: state.validation,
            versions: state.versions,
            inspectedVersionId: _inspectedVersion,
            busy: state.isPublishing,
            canRestore: widget.canPublish,
            onInspect: _inspect,
            onRestore: _restore,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        CustomerPreviewRail(
          state: preview,
          onRefresh: _preview.load,
          onLanguageChanged: _preview.setPhoneLanguage,
          onBranchChanged: _preview.selectBranch,
        ),
      ],
    );
  }

  // ---------- الهاتف ----------

  Widget _phone(
    BuildContext context,
    AppBuilderState state,
    CustomerPreviewState preview,
    DesignNode root,
  ) {
    final labels = SimulatorLabels(preview.language);
    final now = DateTime.now();
    final screen = state.isPreview
        ? _previewScreen(state, preview, labels, now)
        : DesignCanvas(
            document: state.document!,
            page: state.page,
            root: root,
            scope: _scope(state, preview, labels, now),
            selectedId: state.selectedId,
            onSelect: _cubit.select,
            onDrop: _drop,
          );
    final width =
        PhoneFrame.widthFitting(
          maxWidth: MediaQuery.sizeOf(context).width,
          maxHeight: MediaQuery.sizeOf(context).height,
        ) *
        _zoom;
    return Column(
      children: [
        PhoneFrame(
          width: width,
          child: Column(
            children: [
              SimulatorStatusBar(timeLabel: labels.statusBarTime(now)),
              Expanded(child: screen),
              SimulatorBottomBar(
                tab: _tabOfPage(state.page) ?? preview.tab,
                labels: labels,
                onSelect: _selectTab,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          state.isPreview ? S.builderPreviewOnlyNavigation : '',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: adminMutedColor(Theme.of(context)),
            fontSize: AppFontSizes.size10,
            fontWeight: AppFontWeights.regular,
            height: AppTextHeights.line1_4,
          ),
        ),
      ],
    );
  }

  /// المشاهدة هي شاشة الزبون: التنقل يعمل، والسلّة لا تُلمس، والصفحة المقفولة
  /// تبقى على شاشتها التي تشرح سبب قفلها.
  Widget _previewScreen(
    AppBuilderState state,
    CustomerPreviewState preview,
    SimulatorLabels labels,
    DateTime now,
  ) {
    final shown = state.shown;
    if (shown == null) return const SizedBox.shrink();
    return SimulatorViewport(
      state: preview,
      document: shown,
      page: _hasRoot(shown, state.page) ? state.page : null,
      onSelectTab: _selectTab,
      onSelectCategory: _preview.selectCategory,
      onSearchChanged: _preview.updateQuery,
      onRefresh: _preview.load,
    );
  }

  DesignRenderScope _scope(
    AppBuilderState state,
    CustomerPreviewState preview,
    SimulatorLabels labels,
    DateTime now,
  ) {
    return DesignRenderScope(
      feed: preview.feed!,
      language: preview.language,
      labels: labels,
      now: now,
      query: preview.query,
      categoryId: preview.activeCategory?.id,
      // في التحرير تُقرأ النقرات ولا تُنفَّذ: اللوحة تحدّد الطبقة، والكتابة على
      // الشجرة من مقبضها لا من شاشة الزبون.
      onSearchChanged: (_) {},
      onSelectCategory: (_) {},
      onNavigate: (page) => _cubit.openPage(page),
      onOpenProduct: (_) {},
    );
  }

  // ---------- الأوامر ----------

  /// إفلات من المكتبة أو من الطبقات: نقل أو إضافة، والمحرّر يرفض ما يرفضه
  /// السجل فتُسمّى الرفض للموظف.
  void _drop(BuilderDrag drag, String parentId, int index) {
    final existing = drag.existingId;
    _apply(
      existing == null
          ? _cubit.insert(type: drag.type, parentId: parentId, index: index)
          : _cubit.move(id: existing, newParentId: parentId, index: index),
    );
  }

  /// أعلى/أسفل بين الإخوة، وهو ما تُطبَّق عليه نفس قواعد الإفلات.
  void _move(DesignNode root, String id, int delta) {
    final parent = DesignTree.parentOf(root, id);
    final node = DesignTree.find(root, id);
    if (parent == null || node == null) return;
    final index = parent.children.indexWhere((child) => child.id == id);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= parent.children.length) return;
    _apply(_cubit.move(id: id, newParentId: parent.id, index: target));
  }

  void _selectTab(SimulatorTab tab) {
    final page = _pageOfTab(tab);
    _preview.selectTab(tab);
    if (page != null) _cubit.openPage(page);
  }

  void _inspect(String versionId) {
    setState(() => _inspectedVersion = versionId);
    _cubit.inspectVersion(versionId);
  }

  Future<void> _restore(String versionId) async {
    final restored = await _cubit.restoreVersion(versionId);
    if (!mounted) return;
    setState(() => _inspectedVersion = null);
    _showMessage(restored ? S.builderRestore : S.builderVersionMissing);
  }

  void _apply(DesignEditRejection rejection) {
    if (rejection == DesignEditRejection.none) return;
    _showMessage(S.builderRejection(rejection.name));
  }

  void _showMessage(String message) {
    if (message.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ---------- خرائط التبويب ----------

  /// هل للصفحة جذر في هذا المستند؟ بغيابه تبقى شاشة الهاتف على ما تعرضه
  /// القاعدة، ولا تُفتح لوحة على فراغ.
  bool _hasRoot(DesignDocument document, AppPage page) =>
      document.rootOf(page) != null;
}

/// التبويب الذي يعرض الصفحة، وnull لما لا تبويب له أسفل الشاشة.
SimulatorTab? _tabOfPage(AppPage page) => switch (page) {
  AppPage.home => SimulatorTab.home,
  AppPage.categories => SimulatorTab.categories,
  AppPage.cart => SimulatorTab.cart,
  AppPage.favourites => SimulatorTab.favourites,
  AppPage.settings => SimulatorTab.settings,
  AppPage.search || AppPage.productDetails => null,
};

/// صفحة التبويب الذي يقف عليه الهاتف.
AppPage? _pageOfTab(SimulatorTab tab) => switch (tab) {
  SimulatorTab.home => AppPage.home,
  SimulatorTab.categories => AppPage.categories,
  SimulatorTab.cart => AppPage.cart,
  SimulatorTab.favourites => AppPage.favourites,
  SimulatorTab.settings => AppPage.settings,
};
