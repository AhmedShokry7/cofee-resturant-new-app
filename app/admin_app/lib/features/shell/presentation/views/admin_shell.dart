import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/core/navigation/admin_destination.dart';
import 'package:admin_app/core/navigation/admin_navigator.dart';
import 'package:admin_app/core/navigation/admin_product_options_host.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/audit/presentation/pages/audit_log_page.dart';
import 'package:admin_app/features/ai_knowledge/presentation/pages/ai_knowledge_page.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:admin_app/features/banners/presentation/pages/banner_page.dart';
import 'package:admin_app/features/branches/presentation/pages/branch_page.dart';
import 'package:admin_app/features/bundles/presentation/pages/bundle_page.dart';
import 'package:admin_app/features/carts/presentation/pages/cart_page.dart';
import 'package:admin_app/features/catalog/presentation/pages/category_page.dart';
import 'package:admin_app/features/catalog/presentation/pages/product_page.dart';
import 'package:admin_app/features/coupons/presentation/pages/coupons_page.dart';

import 'package:admin_app/features/customers/presentation/pages/customer_page.dart';
import 'package:admin_app/features/visual_editor/presentation/pages/visual_editor_page.dart';
import 'package:admin_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:admin_app/features/inventory/presentation/pages/inventory_page.dart';
import 'package:admin_app/features/inventory/presentation/pages/stock_movements_page.dart';
import 'package:admin_app/features/hr/attendance/presentation/hr_attendance_page.dart';
import 'package:admin_app/features/hr/schedules/presentation/hr_schedules_page.dart';
import 'package:admin_app/features/hr/leave/presentation/pages/hr_leave_page.dart';
import 'package:admin_app/features/hr/payroll/presentation/hr_payroll_page.dart';
import 'package:admin_app/features/hr/dashboard/hr_dashboard_page.dart';
import 'package:admin_app/features/hr/offboarding/presentation/hr_offboarding_page.dart';
import 'package:admin_app/features/hr/finance/presentation/pages/hr_finance_page.dart';
import 'package:admin_app/features/hr/compensation/presentation/hr_compensation_page.dart';
import 'package:admin_app/features/hr/settings/hr_settings_page.dart';
import 'package:admin_app/features/kitchen/presentation/pages/kitchen_page.dart';
import 'package:admin_app/features/loyalty/presentation/pages/loyalty_page.dart';
import 'package:admin_app/features/marketing/presentation/pages/marketing_hub_page.dart';
import 'package:admin_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:admin_app/features/email_design/presentation/email_design_page.dart';
import 'package:admin_app/features/option_groups/presentation/pages/option_group_page.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/product_option_dialog.dart';
import 'package:admin_app/features/orders/presentation/pages/order_page.dart';
import 'package:admin_app/features/payments/presentation/pages/payment_page.dart';
import 'package:admin_app/features/pos/presentation/pages/pos_page.dart';
import 'package:admin_app/features/reviews/presentation/pages/reviews_page.dart';
import 'package:admin_app/features/roles/presentation/pages/role_page.dart';
import 'package:admin_app/features/shell/data/models/admin_nav_counts.dart';
import 'package:admin_app/features/shell/presentation/manager/admin_nav_cubit.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destinations.dart';
import 'package:admin_app/features/shell/presentation/models/admin_shell_layout_data.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_desktop_layout.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_mobile_layout.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_more_page.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_sign_out_dialog.dart';
import 'package:admin_app/features/staff/presentation/pages/staff_page.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/pages/subscription_plan_page.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/pages/subscription_admin_page.dart';
import 'package:admin_app/features/tables/presentation/pages/tables_page.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_feature_placeholder.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The frame around every admin page.
///
/// It owns the selected destination, the search state, the sidebar work
/// counters and the sign out flow, then hands everything to the desktop or the
/// mobile layout.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.session});

  final AdminSession session;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with WidgetsBindingObserver {
  /// Below this width an immersive page moves navigation into a drawer.
  static const double _immersiveMinWidth = 1380;

  String _selectedId = 'dashboard';

  final TextEditingController _searchTextController = TextEditingController();
  final AdminSearchController _searchController = AdminSearchController();
  late final AdminNavCubit _navCubit;

  /// The destinations a visit built already, in the order they were opened.
  ///
  /// A page that was opened once stays mounted behind an `Offstage`: going
  /// back to it is a paint switch, not a network round trip. Its cubit keeps
  /// the data, its live feed keeps it fresh, and the shell hands it a fresh
  /// widget only when it becomes the visible one again.
  final Set<String> _visitedIds = <String>{};

  /// The page a destination built last, and the locale it was built under.
  /// A cached page is reused untouched while its locale stands, so counter
  /// updates and language-independent shell rebuilds never re-walk a page.
  final Map<String, (Widget, Locale)> _pageCache = <String, (Widget, Locale)>{};

  @override
  void initState() {
    super.initState();
    _navCubit = AdminNavCubit();
    WidgetsBinding.instance.addObserver(this);
    _navCubit.start(
      watchOrders: widget.session.hasPermission('orders.read'),
      watchKitchen: widget.session.hasPermission('kitchen.read'),
      watchNotifications: widget.session.hasPermission('notifications.read'),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navCubit.close();
    _searchTextController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _navCubit.refresh();
  }

  List<AdminDestination> get _destinations =>
      adminDestinations.where((destination) {
        final hasPrimary =
            destination.permission == null ||
            widget.session.hasPermission(destination.permission!);
        final hasAny =
            destination.anyPermissions.isEmpty ||
            destination.anyPermissions.any(widget.session.hasPermission);
        final hasAll = destination.requiredPermissions.every(
          widget.session.hasPermission,
        );
        return hasPrimary && hasAny && hasAll;
      }).toList();

  /// القسم المعروض، ولا شيء حين لا يملك الحساب قسمًا واحدًا.
  ///
  /// الإطار يرسم نفسه بلا وجهات حتى يبقى زر تسجيل الخروج متاحًا؛ فلو تعطل
  /// البناء هنا يتجمد شاشة الموظف بلا مخرج.
  AdminDestination? get _selected {
    final destinations = _destinations;
    if (destinations.isEmpty) return null;
    for (final destination in destinations) {
      if (destination.id == _selectedId) return destination;
    }
    return destinations.first;
  }

  void _select(String id) {
    setState(() {
      if (id != _selectedId) {
        _selectedId = id;
        // The kept-alive page shows again: its state survives, and the fresh
        // widget makes it rebind the search of the shell inside
        // `didUpdateWidget` — no remount, no refetch.
        _pageCache.remove(id);
      }
      // The page that is leaving receives the empty query while it is still
      // bound, so its own filter state matches the cleared app bar.
      _searchController.clear();
      _searchTextController.clear();
    });
    _navCubit.refresh();
  }

  /// يفتح حوار أحجام مشروب واحد وإضافاته من أي بطاقة منتج.
  ///
  /// هنا لا في شاشة المنتجات: القشرة وحدها تعرف الفيتشرين، والكتابة تقرر
  /// القاعدة بها سياسةً لكل صفّ.
  Future<void> _openProductOptions(AdminProduct product) =>
      showProductOptionsDialog(context: context, product: product);

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showAdminSignOutDialog(context);

    if (shouldSignOut && mounted) {
      context.read<AuthBloc>().add(const AuthSignOutRequested());
    }
  }

  /// Every visited page, one on top of the other, only the selected one
  /// visible.
  ///
  /// The stack keeps the element tree of each visited page alive: switching
  /// destinations is instant, and the identical cached widget lets a shell
  /// rebuild — a new badge count, a theme flip — skip the hidden pages and
  /// the visible one entirely.
  Widget _buildContent() {
    // Every feature is listed from the database. The ones that are built show
    // their page, the rest show the shared placeholder with their tables.
    final destination = _selected;
    if (destination == null) return const _NoAccessPage();
    _visitedIds.add(destination.id);
    final locale = AppLocale.instance.locale;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        for (final id in _visitedIds)
          Offstage(
            offstage: id != _selectedId,
            child: KeyedSubtree(
              key: ValueKey(id),
              child: _cachedPage(id, locale),
            ),
          ),
      ],
    );
  }

  /// The page of a visited destination, rebuilt only when it has to be.
  ///
  /// A fresh widget is made when the destination is opened for the first
  /// time, when the panel language changed since it was built, or when the
  /// destination becomes the visible one again — the last one lets the page
  /// rebind the search in `didUpdateWidget` without refetching its data.
  Widget _cachedPage(String id, Locale locale) {
    final cached = _pageCache[id];
    if (cached != null && cached.$2 == locale) return cached.$1;
    final destinations = _destinations;
    final destination = destinations.firstWhere(
      (candidate) => candidate.id == id,
      orElse: () => destinations.first,
    );
    final page = _pageFor(destination);
    _pageCache[id] = (page, locale);
    return page;
  }

  /// The page of a destination.
  ///
  /// Add a case here when a feature is built; every destination without a
  /// page keeps showing the placeholder.
  Widget _pageFor(AdminDestination destination) {
    switch (destination.id) {
      case 'more':
        return AdminMorePage(
          destinations: _destinations,
          selectedId: destination.id,
          onSelect: _select,
        );
      case 'visualEditor':
        return VisualEditorPage(
          canPublish: widget.session.hasPermission('design.publish'),
          imagePermissions: widget.session.permissions,
        );
      case 'dashboard':
        return DashboardPage(
          searchController: _searchController,
          staffName: widget.session.fullName,
          canManageTarget:
              widget.session.canManageAllBranches &&
              widget.session.hasPermission('settings.write'),
          canAddProduct:
              widget.session.hasPermission('catalog.product.write') ||
              widget.session.isOwner,
        );
      case 'products':
        return ProductPage(
          searchController: _searchController,
          // 117 و184 ترفض كل كتابة منتج أو باقة بلا catalog.product.write،
          // و117 تطلب catalog.category.write لفئة جديدة من داخل حوار المنتج.
          canManage: widget.session.hasPermission('catalog.product.write'),
          canManageCategories: widget.session.hasPermission(
            'catalog.category.write',
          ),
        );
      case 'categories':
        return CategoryPage(searchController: _searchController);
      case 'branches':
        return BranchPage(
          searchController: _searchController,
          canManage:
              widget.session.hasPermission('settings.write') ||
              widget.session.isOwner,
          canManagePricing:
              widget.session.hasPermission('catalog.product.write') ||
              widget.session.isOwner,
        );
      case 'auditLog':
        return AuditLogPage(searchController: _searchController);
      case 'bundles':
        return BundlePage(
          searchController: _searchController,
          canManage: widget.session.hasPermission('catalog.product.write'),
        );
      case 'optionGroups':
        return OptionGroupPage(
          searchController: _searchController,
          // 020 و224 تطلبان catalog.product.write لكل كتابة على المجموعات
          // وقيمها ونطاقها، فلا أدوات كتابة لمن يُرفض حفظه دائمًا.
          canManage: widget.session.hasPermission('catalog.product.write'),
        );
      case 'payments':
        return PaymentPage(searchController: _searchController);
      case 'pos':
        return PosPage(searchController: _searchController);
      case 'orders':
        return OrderPage(
          searchController: _searchController,
          // كل كتابة على الطلب تطلبها القاعدة بصلاحية orders.status.update،
          // فتُعرض أدوات التغيير لمن يملكها فقط بدل أزرار تُرفض دائمًا.
          canManage: widget.session.hasPermission('orders.status.update'),
        );
      case 'banners':
        return BannerPage(
          searchController: _searchController,
          // سياسة 022 تطلب settings.write لكل كتابة على البانر، فلا أدوات
          // كتابة لمن تُرفض كتابته دائمًا.
          canManage: widget.session.hasPermission('settings.write'),
        );
      case 'carts':
        return CartPage(searchController: _searchController);
      case 'customers':
        return CustomerPage(
          searchController: _searchController,
          canManage:
              widget.session.hasPermission('customers.write') ||
              widget.session.isOwner,
        );
      case 'kitchen':
        return KitchenPage(
          searchController: _searchController,
          canManage:
              widget.session.hasPermission('kitchen.manage') ||
              widget.session.isOwner,
        );
      case 'tables':
        return TablesPage(
          canManage:
              widget.session.hasPermission('tables.manage') ||
              widget.session.isOwner,
        );
      case 'inventory':
        return InventoryPage(
          searchController: _searchController,
          canAdjust: widget.session.hasPermission('inventory.adjust'),
          canEdit:
              widget.session.hasPermission('inventory.adjust') &&
              widget.session.canManageAllBranches,
        );
      case 'stockMovements':
        return StockMovementsPage(
          searchController: _searchController,
          canAdjust: widget.session.hasPermission('inventory.adjust'),
        );
      case 'staff':
        return StaffPage(
          searchController: _searchController,
          canManagePermissions:
              widget.session.hasPermission('admin.staff.write') ||
              widget.session.isOwner,
          canReadEmployeeFiles: widget.session.hasPermission(
            'hr.employee.read',
          ),
          canWriteEmployeeFiles: widget.session.hasPermission(
            'hr.employee.write',
          ),
        );
      case 'hrAttendance':
        return HrAttendancePage(
          searchController: _searchController,
          canReview: widget.session.hasPermission('hr.attendance.manage'),
        );
      case 'hrDashboard':
        return const HrDashboardPage();
      case 'hrSchedules':
        return HrSchedulesPage(
          canManage: widget.session.hasPermission('hr.schedule.manage'),
          canReadEmployees: widget.session.hasPermission('hr.employee.read'),
        );
      case 'hrLeave':
        return HrLeavePage(
          canReview: widget.session.hasPermission('hr.leave.review'),
          canManageTypes: widget.session.hasPermission('hr.settings.manage'),
        );
      case 'hrPayroll':
        return HrPayrollPage(
          canRead: widget.session.hasPermission('hr.payroll.read'),
          canPrepare: widget.session.hasPermission('hr.payroll.manage'),
          canApprove: widget.session.hasPermission('hr.payroll.approve'),
          canPay: widget.session.hasPermission('hr.payroll.pay'),
        );
      case 'hrOffboarding':
        return HrOffboardingPage(
          canRead: widget.session.hasPermission('hr.employee.read'),
          canWrite: widget.session.hasPermission('hr.employee.write'),
        );
      case 'hrFinance':
        return HrFinancePage(
          canManage: widget.session.hasPermission('hr.finance.adjust'),
          canReadEmployees: widget.session.hasPermission('hr.employee.read'),
        );
      case 'hrCompensation':
        return const HrCompensationPage(canManage: true);
      case 'hrSettings':
        return const HrSettingsPage();
      case 'roles':
        return RolePage(
          searchController: _searchController,
          canManage:
              widget.session.hasPermission('admin.role.write') ||
              widget.session.isOwner,
        );
      case 'subscriptions':
        return SubscriptionAdminPage(searchController: _searchController);
      case 'subscriptionPlans':
        return SubscriptionPlanPage(searchController: _searchController);
      case 'loyalty':
        return LoyaltyPage(
          searchController: _searchController,
          canManage:
              widget.session.hasPermission('loyalty.write') ||
              widget.session.isOwner,
        );
      case 'coupons':
        return CouponsPage(
          searchController: _searchController,
          canManage:
              widget.session.hasPermission('settings.write') ||
              widget.session.isOwner,
        );
      case 'reviews':
        return ReviewsPage(
          searchController: _searchController,
          canManage:
              widget.session.hasPermission('reviews.moderate') ||
              widget.session.isOwner,
        );
      case 'notifications':
        return NotificationsPage(
          searchController: _searchController,
          canSend:
              widget.session.hasPermission('notifications.send') ||
              widget.session.isOwner,
          canManage:
              widget.session.hasPermission('notifications.manage') ||
              widget.session.isOwner,
        );
      case 'emailDesign':
        return const EmailDesignPage();
      case 'marketing':
        return MarketingHubPage(
          canCreate:
              widget.session.hasPermission('marketing.create') ||
              widget.session.isOwner,
          canReview:
              widget.session.hasPermission('marketing.review') ||
              widget.session.isOwner,
          canSchedule:
              widget.session.hasPermission('marketing.schedule') ||
              widget.session.isOwner,
          canSend:
              widget.session.hasPermission('marketing.send') ||
              widget.session.isOwner,
          canReadConsent:
              widget.session.hasPermission('marketing.consent.read') ||
              widget.session.isOwner,
        );
      case 'aiKnowledge':
        return AiKnowledgePage(
          searchController: _searchController,
          canManage: widget.session.hasPermission('settings.write'),
        );
      default:
        return AdminFeaturePlaceholder(destination: destination);
    }
  }

  AdminShellLayoutData _buildLayoutData(AdminNavCounts counts) {
    final destination = _selected;
    return AdminShellLayoutData(
      session: widget.session,
      destinations: _destinations,
      selectedId: destination?.id ?? '',
      onSelected: _select,
      onSignOut: _confirmSignOut,
      searchController: _searchController,
      searchTextController: _searchTextController,
      // HR pages render their own descriptive page header; repeating the same
      // title in the toolbar made the screens feel crowded and ambiguous.
      title: destination?.id.startsWith('hr') == true
          ? ''
          : destination?.label ?? S.noAccessTitle,
      // بلا قسم لا شيء يُبحث، فيتراجع شريط الأدوات عن حقل البحث.
      searchHint: destination?.searchHint ?? '',
      badges: <String, int>{
        if (counts.unreadOrders > 0) 'orders': counts.unreadOrders,
        if (counts.unreadKitchen > 0) 'kitchen': counts.unreadKitchen,
        if (counts.unreadNotifications > 0)
          'notifications': counts.unreadNotifications,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // The text of the panel is read while the shell builds. The shell listens
    // to the language of the panel, so a language switch re-labels the
    // sidebar, the app bar and the page right away, without a restart.
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) => BlocProvider<AdminNavCubit>.value(
        value: _navCubit,
        child: BlocBuilder<AdminNavCubit, AdminNavCounts>(
          builder: (context, counts) => _buildShell(context, counts),
        ),
      ),
    );
  }

  Widget _buildShell(BuildContext context, AdminNavCounts counts) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppBreakpoints.adminDesktopShell;
    final data = _buildLayoutData(counts);
    // الصفحات تُبنى تحت اليد نفسها: رابط «كل الطلبات» داخل بطاقة ينادي
    // `_select` هنا، فلا صفحة تملك قرارًا هو للقشرة.
    //
    // ويد الحوار ملكها هي الأخرى: شاشة المنتجات في `catalog` وحوار الأحجام في
    // `option_groups`، وفيتشر لا يستورد فيتشرًا — فتعير القشرة يدها لمن يملك
    // `catalog.product.write`، ولا يعرض المنتج عنايته بلا يد.
    final canPriceProducts = widget.session.hasPermission(
      'catalog.product.write',
    );
    final content = AdminProductOptionsHost(
      onOpen: canPriceProducts ? _openProductOptions : null,
      child: AdminNavigator(onSelect: _select, child: _buildContent()),
    );

    if (isWide) {
      return AdminDesktopLayout(
        data: data,
        content: content,
        collapseSidebar:
            _selected?.immersive == true && width < _immersiveMinWidth,
        fullWidthContent: _selected?.immersive == true,
      );
    }

    return AdminMobileLayout(data: data, content: content);
  }
}

/// ما يراه حساب لا يملك أي صلاحية: رسالة صريحة بدل قسم مسروق أو شاشة متعطلة.
class _NoAccessPage extends StatelessWidget {
  const _NoAccessPage();

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: AdminEmptyState(
        icon: AppIcons.blocked,
        message: S.noAccessMessage,
      ),
    );
  }
}
