import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/customer_feed.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/entities/preview_product.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/design_renderer.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_labels.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_notice_screen.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_product_details_screen.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_product_grid.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_section_heading.dart';

/// شاشة فتحها التنقل من فوق صفحة المستند.
///
/// التنقل داخل الهاتف حقيقي لا صورة: ما يضغطه الزبون يبدّل الشاشة المعروضة،
/// وكل شاشة تُبنى من المستند نفسه والبيانات نفسها.
sealed class _Trip {
  const _Trip();
}

/// صفحة من صفحات التطبيق فتحها إجراء، كصفحة البحث.
class _OpenedPage extends _Trip {
  const _OpenedPage(this.page);

  final AppPage page;
}

/// صفحة كل صفوف شريط، كما يفتحها «عرض المزيد»: الشريط يكتفي بعشر بطاقات
/// والبقية هنا.
class _OpenedStrip extends _Trip {
  const _OpenedStrip(this.source);

  final DesignNode source;
}

/// تفاصيل منتج فتحه إجراء على عقدة.
class _OpenedProduct extends _Trip {
  const _OpenedProduct(this.product);

  final PreviewProduct product;
}

/// صفحة من مستند التصميم داخل الهاتف، بكل تنقلاتها.
///
/// الصفحة هنا هي جذر [page] من [document] كما يركّبه `DesignRenderer`، والتنقل
/// يضيف فوقها شاشة لا يفتح نافذة خارج الهاتف: الموظف يرى ما يراه الزبون في
/// الجهاز نفسه. الكتابة في البحث تُبدل جسم الصفحة بنتائجها كما في `HomePageBody`
/// عند العميل، و«عرض المزيد» يفتح كل صفوف الشريط بلا سقف.
class DesignSimulatorScreen extends StatefulWidget {
  const DesignSimulatorScreen({
    super.key,
    required this.document,
    required this.page,
    required this.feed,
    required this.language,
    required this.labels,
    required this.now,
    required this.query,
    required this.onSearchChanged,
    required this.onSelectCategory,
    required this.onNavigate,
    this.categoryId,
    this.onRefresh,
    this.decorate,
  });

  final DesignDocument document;

  /// صفحة التبويب الذي يقف عليه الهاتف.
  final AppPage page;

  final CustomerFeed feed;
  final AppLanguage language;
  final SimulatorLabels labels;
  final DateTime now;
  final String query;
  final String? categoryId;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSelectCategory;

  /// تنقل يبدّل التبويب نفسه: اللوحة هي التي تعرف التبويب المعروض.
  final ValueChanged<AppPage> onNavigate;

  final Future<void> Function()? onRefresh;

  /// يلفّ كل عقدة برسمها في لوحة المحرّر: حدود التحديد ومؤشر الإفلات. تبقى null
  /// فيما يراه الزبون، فتختفي العقد المخفية كما تختفي هناك.
  final DesignNodeDecorator? decorate;

  @override
  State<DesignSimulatorScreen> createState() => _DesignSimulatorScreenState();
}

class _DesignSimulatorScreenState extends State<DesignSimulatorScreen> {
  final List<_Trip> _stack = <_Trip>[];

  @override
  void didUpdateWidget(DesignSimulatorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // التبديل إلى تبويب آخر ينقل الموظف إلى شاشة ذلك التبويب، كما يفعل الزبون:
    // الشاشات المفتوحة فوق الصفحة السابقة تُترك خلفه.
    if (widget.page != oldWidget.page) _stack.clear();
  }

  void _push(_Trip trip) => setState(() => _stack.add(trip));

  void _pop() => setState(() => _stack.removeLast());

  @override
  Widget build(BuildContext context) {
    final scope = DesignRenderScope(
      feed: widget.feed,
      language: widget.language,
      labels: widget.labels,
      now: widget.now,
      query: widget.query,
      categoryId: widget.categoryId,
      onSearchChanged: widget.onSearchChanged,
      onSelectCategory: widget.onSelectCategory,
      onNavigate: _onNavigate,
      onOpenProduct: (product) => _push(_OpenedProduct(product)),
      onSeeAll: (node) => _push(_OpenedStrip(node)),
    );
    final trip = _stack.isEmpty ? null : _stack.last;
    final screen = switch (trip) {
      _OpenedProduct(:final product) => SimulatorProductDetailsScreen(
        product: product,
        language: widget.language,
        labels: widget.labels,
        onBack: _pop,
      ),
      _OpenedStrip(:final source) => _stripPage(scope, source),
      _OpenedPage(:final page) => _page(scope, page, withBack: true),
      null => _currentPage(scope),
    };
    final onRefresh = widget.onRefresh;
    if (onRefresh == null) return screen;
    return RefreshIndicator(onRefresh: onRefresh, child: screen);
  }

  /// إجراء تنقّل. صفحة البحث ليست تبويبًا في شريط العميل، فتُفتح فوق الشاشة
  /// الحالية؛ وما عداها يبدّل التبويب فتتولّى اللوحة الأمر.
  void _onNavigate(AppPage page) {
    if (page == AppPage.search) {
      _push(const _OpenedPage(AppPage.search));
      return;
    }
    widget.onNavigate(page);
  }

  /// شاشة التبويب: جذر صفحته، ونتائج البحث مكانها حين يُكتب في الحقل — وهي
  /// حالته عند العميل، فلا حاجة إلى صفحة مفتوحة.
  Widget _currentPage(DesignRenderScope scope) {
    final searching =
        widget.page == AppPage.home && widget.query.trim().isNotEmpty;
    return _page(scope, searching ? AppPage.search : widget.page);
  }

  Widget _page(DesignRenderScope scope, AppPage page, {bool withBack = false}) {
    final root = widget.document.rootOf(page);
    if (root == null) return _noDesign();
    final content = DesignRenderer(
      node: root,
      scope: scope,
      decorate: widget.decorate,
    );
    if (!withBack) return content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackRow(labels: widget.labels, onBack: _pop),
        Expanded(child: content),
      ],
    );
  }

  /// صفحة «عرض المزيد»: كل صفوف مصدر الشريط، لا سقف المقطع. عنوانها عنوان
  /// الشريط، واسم مصدره حين لا عنوان له.
  Widget _stripPage(DesignRenderScope scope, DesignNode source) {
    final products = scope.allProductsOf(source);
    final title = source.stringProperty('title').trim();
    final heading = title.isEmpty ? scope.sourceNameOf(source) : title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: SimulatorSectionHeading(
            title: heading,
            subtitle: scope.seasonalOf(source),
            trailingLabel: widget.labels.back,
            onTapTrailing: _pop,
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? SimulatorNoticeScreen(
                  icon: AppIcons.coffee01,
                  title: widget.labels.noProducts,
                  note: widget.labels.noDesignNote,
                )
              : SimulatorProductGrid(
                  products: products,
                  language: widget.language,
                ),
        ),
      ],
    );
  }

  /// صفحة لا جذر لها في المستند: لا تصميم محفوظ لها، فلا صفوف تُختَرع لها.
  Widget _noDesign() => SimulatorNoticeScreen(
    icon: AppIcons.informationCircle,
    title: widget.labels.noDesignForPage,
    note: widget.labels.noDesignNote,
  );
}

/// سطر رجوع أعلى شاشة مفتوحة، كنصّ لا أيقونة توحي بسلوك لا تؤديه.
class _BackRow extends StatelessWidget {
  const _BackRow({required this.labels, required this.onBack});

  final SimulatorLabels labels;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(onPressed: onBack, child: Text(labels.back)),
      ),
    );
  }
}
