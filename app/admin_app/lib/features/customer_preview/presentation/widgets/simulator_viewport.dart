import 'package:flutter/material.dart';

import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/customer_feed.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/simulator_tab.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/customer_preview_state.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/design_simulator_screen.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_bottom_bar.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_categories_screen.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_home_screen.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_labels.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_notice_screen.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_status_bar.dart';

/// جوف الهاتف: شريط الحالة، الشاشة التي يقف عليها التبويب، وشريط التنقل.
///
/// الاتجاه هنا اتجاه الهاتف لا اتجاه اللوحة: الموظف قد يقلّب لغة المعاينة
/// واللوحة حولها ثابتة. والوقت يُقرأ مرة واحدة هنا، فالتحية وشريط الحالة
/// يتغيّران معًا لا أمام بعضهما.
class SimulatorViewport extends StatelessWidget {
  const SimulatorViewport({
    super.key,
    required this.state,
    required this.onSelectTab,
    required this.onSelectCategory,
    required this.onSearchChanged,
    this.onRefresh,
    this.document,
    this.page,
  });

  final CustomerPreviewState state;
  final ValueChanged<SimulatorTab> onSelectTab;
  final ValueChanged<String> onSelectCategory;
  final ValueChanged<String> onSearchChanged;

  /// سحب الهاتف يعيد القراءة من اللوحة، كما يسحب الزبون صفحته.
  final Future<void> Function()? onRefresh;

  /// مستند التصميم المعروض داخل الهاتف بدل الشاشة المبنية يدويًا. null يعني
  /// المحاكي المعتاد: لا تُعرض صفحة نصف مبنية حين لا حفظ بعد، ولا يُهدم مسار
  /// قائم لأن المحرّر لم يُنتج شيئًا.
  final DesignDocument? document;

  /// الصفحة التي تُفتح داخل الهاتف، تتقدم على تبويب الشريط. null تعني ما يقف
  /// عليه التبويب نفسه — وهو حال محاكي العميل وحده، بينما المحرّر يفتح صفحة
  /// يسمّيها الموظف من شريطه، ومنها بحث لا تبويب له أسفل الشاشة.
  final AppPage? page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = SimulatorLabels(state.language);
    final feed = state.feed;
    final now = DateTime.now();
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Directionality(
        textDirection: state.textDirection,
        child: Column(
          children: [
            SimulatorStatusBar(timeLabel: labels.statusBarTime(now)),
            Expanded(
              child: feed == null
                  ? const SizedBox.shrink()
                  : _screen(context, feed, labels, now),
            ),
            SimulatorBottomBar(
              tab: state.tab,
              labels: labels,
              onSelect: onSelectTab,
            ),
          ],
        ),
      ),
    );
  }

  Widget _screen(
    BuildContext context,
    CustomerFeed feed,
    SimulatorLabels labels,
    DateTime now,
  ) {
    final document = this.document;
    // جذر الصفحة يجب أن يكون في المستند: صفحة مقفولة لا جذر لها تبقى على
    // شاشتها التي تشرح سبب قفلها، ولا تُعرض صفحة نصف مبنية.
    final target = page ?? _editablePageOf(state.tab);
    if (document != null &&
        target != null &&
        document.rootOf(target) != null) {
      return DesignSimulatorScreen(
        document: document,
        page: target,
        feed: feed,
        language: state.language,
        labels: labels,
        now: now,
        query: state.query,
        categoryId: state.activeCategory?.id,
        onSearchChanged: onSearchChanged,
        onSelectCategory: onSelectCategory,
        onNavigate: _gotoTab,
        onRefresh: onRefresh,
      );
    }
    switch (state.tab) {
      case SimulatorTab.home:
        return SimulatorHomeScreen(
          feed: feed,
          language: state.language,
          labels: labels,
          query: state.query,
          now: now,
          onSearchChanged: onSearchChanged,
          onSelectCategory: onSelectCategory,
          onSeeAllCategories: () => onSelectTab(SimulatorTab.categories),
          onRefresh: onRefresh,
        );
      case SimulatorTab.categories:
        return SimulatorCategoriesScreen(
          feed: feed,
          language: state.language,
          labels: labels,
          category: state.activeCategory,
          products: state.categoryProducts,
          onSelectCategory: onSelectCategory,
        );
      case SimulatorTab.cart:
        return SimulatorNoticeScreen(
          icon: AppIcons.shoppingCart01,
          title: labels.emptyCart,
          note: labels.emptyCartHint,
        );
      case SimulatorTab.favourites:
        return SimulatorNoticeScreen(
          icon: AppIcons.star,
          title: labels.emptyFavourites,
          note: labels.favouritesHint,
        );
      case SimulatorTab.settings:
        return SimulatorNoticeScreen(
          icon: AppIcons.settings01,
          title: labels.tabLabel(SimulatorTab.settings),
          note: labels.settingsNote,
        );
    }
  }

  /// التبويب الذي له صفحة في المستند. المقفلة منها لا جذر لها، فتبقى على
  /// شاشتها التي تشرح سبب قفلها بدل صفحة نصف مبنية.
  static AppPage? _editablePageOf(SimulatorTab tab) => switch (tab) {
    SimulatorTab.home => AppPage.home,
    SimulatorTab.categories => AppPage.categories,
    _ => null,
  };

  /// تبويب شريط التنقل الذي يعرض الصفحة، وnull لما يفتحه الهاتف فوق التبويب
  /// نفسه كصفحة البحث وتفاصيل المنتج.
  static SimulatorTab? _tabOf(AppPage page) => switch (page) {
    AppPage.home => SimulatorTab.home,
    AppPage.categories => SimulatorTab.categories,
    AppPage.cart => SimulatorTab.cart,
    AppPage.favourites => SimulatorTab.favourites,
    AppPage.settings => SimulatorTab.settings,
    AppPage.search => null,
    AppPage.productDetails => null,
  };

  void _gotoTab(AppPage page) {
    final tab = _tabOf(page);
    if (tab != null) onSelectTab(tab);
  }
}
