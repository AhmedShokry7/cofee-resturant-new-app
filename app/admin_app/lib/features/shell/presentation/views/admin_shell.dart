import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/navigation/admin_destination.dart';
import 'package:admin_app/core/navigation/admin_navigator.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/audit/presentation/pages/audit_log_page.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:admin_app/features/banners/presentation/pages/banner_page.dart';
import 'package:admin_app/features/branches/presentation/pages/branch_page.dart';
import 'package:admin_app/features/bundles/presentation/pages/bundle_page.dart';
import 'package:admin_app/features/carts/presentation/pages/cart_page.dart';
import 'package:admin_app/features/catalog/presentation/pages/category_page.dart';
import 'package:admin_app/features/catalog/presentation/pages/product_page.dart';
import 'package:admin_app/features/coupons/presentation/pages/coupons_page.dart';
import 'package:admin_app/features/customer_preview/data/repositories/supabase_app_builder_repository.dart';
import 'package:admin_app/features/customer_preview/presentation/pages/app_builder_page.dart';
import 'package:admin_app/features/customer_preview/presentation/pages/customer_preview_page.dart';
import 'package:admin_app/features/customers/presentation/pages/customer_page.dart';
import 'package:admin_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:admin_app/features/hr/presentation/pages/hr_advances_page.dart';
import 'package:admin_app/features/hr/presentation/pages/hr_attendance_page.dart';
import 'package:admin_app/features/hr/presentation/pages/hr_dashboard_page.dart';
import 'package:admin_app/features/hr/presentation/pages/hr_discrepancies_page.dart';
import 'package:admin_app/features/hr/presentation/pages/hr_employees_page.dart';
import 'package:admin_app/features/hr/presentation/pages/hr_leave_page.dart';
import 'package:admin_app/features/hr/presentation/pages/hr_my_day_page.dart';
import 'package:admin_app/features/hr/presentation/pages/hr_payroll_page.dart';
import 'package:admin_app/features/hr/presentation/pages/hr_schedules_page.dart';
import 'package:admin_app/features/hr/presentation/pages/hr_settings_page.dart';
import 'package:admin_app/features/inventory/presentation/pages/inventory_page.dart';
import 'package:admin_app/features/inventory/presentation/pages/stock_movements_page.dart';
import 'package:admin_app/features/kitchen/presentation/pages/kitchen_page.dart';
import 'package:admin_app/features/loyalty/presentation/pages/loyalty_page.dart';
import 'package:admin_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:admin_app/features/option_groups/presentation/pages/option_group_page.dart';
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
import 'package:admin_app/features/shell/presentation/widgets/admin_sign_out_dialog.dart';
import 'package:admin_app/features/staff/presentation/pages/staff_page.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/pages/subscription_plan_page.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/pages/subscription_admin_page.dart';
import 'package:admin_app/features/tables/presentation/pages/tables_page.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_feature_placeholder.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:flutter/material.dart';
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
  /// Below this width a workspace page keeps its full width and moves the
  /// navigation into a drawer.
  static const double _immersiveMinWidth = 1380;

  String _selectedId = 'dashboard';

  final TextEditingController _searchTextController = TextEditingController();
  final AdminSearchController _searchController = AdminSearchController();
  late final AdminNavCubit _navCubit;

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

  List<AdminDestination> get _destinations => adminDestinations
      .where(
        (destination) =>
            destination.permission == null ||
            widget.session.hasPermission(destination.permission!),
      )
      .toList();

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
      _selectedId = id;
      _searchController.bind(null);
      _searchController.clear();
      _searchTextController.clear();
    });
    _navCubit.refresh();
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showAdminSignOutDialog(context);

    if (shouldSignOut && mounted) {
      context.read<AuthBloc>().add(const AuthSignOutRequested());
    }
  }

  Widget _buildContent() {
    // Every feature is listed from the database. The ones that are built show
    // their page, the rest show the shared placeholder with their tables.
    final destination = _selected;
    if (destination == null) return const _NoAccessPage();
    final page = _pageFor(destination);

    return KeyedSubtree(key: ValueKey(destination.id), child: page);
  }

  /// The page of a destination.
  ///
  /// Add a case here when a feature is built; every destination without a
  /// page keeps showing the placeholder.
  Widget _pageFor(AdminDestination destination) {
    switch (destination.id) {
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
      case 'customerPreview':
        return const CustomerPreviewPage();
      case 'appBuilder':
        // 226 تحمل الصلاحيين في القاعدة، واللوحة تفتح ما يملكه الموظف منه:
        // النشر والرجوع بـ design.publish، والتحرير والحفظ بـ design.edit.
        // الإطفاء راحة، والرفض 42501 هو الحماية.
        return AppBuilderPage(
          repository: SupabaseAppBuilderRepository(),
          canEdit: widget.session.hasPermission('design.edit'),
          canPublish: widget.session.hasPermission('design.publish'),
        );
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
        );
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
      case 'hrMyDay':
        // البصمة وقسيممة الأجر وطلب الإجازة حقٌّ لكل موظف، فلا إذن هنا:
        // تعرف القاعدة من أنت من الجلسة نفسها.
        return HrMyDayPage(searchController: _searchController);
      case 'hrDashboard':
        return const HrDashboardPage();
      case 'hrEmployees':
        return HrEmployeesPage(
          searchController: _searchController,
          canManage: widget.session.hasPermission('hr.employee.write'),
          // الأجر صلاحية مستقلة في 212، فلا تُوهَب لمن يعدّل العقد.
          canManageCompensation: widget.session.hasPermission(
            'hr.compensation.manage',
          ),
        );
      case 'hrAttendance':
        // مراجعة التصحيح في `hr.attendance.manage` لا في قراءة السطور.
        return HrAttendancePage(
          searchController: _searchController,
          canReview: widget.session.hasPermission('hr.attendance.manage'),
        );
      case 'hrSchedules':
        return HrSchedulesPage(
          searchController: _searchController,
          canManage: widget.session.hasPermission('hr.schedule.manage'),
        );
      case 'hrLeave':
        return HrLeavePage(
          searchController: _searchController,
          canReview: widget.session.hasPermission('hr.leave.review'),
        );
      case 'hrPayroll':
        // ثلاثة أدوار لثلاثة أزرار: من يولّد لا يعتمد، ومن يعتمد لا يصرف.
        return HrPayrollPage(
          searchController: _searchController,
          canManage: widget.session.hasPermission('hr.payroll.manage'),
          canApprove: widget.session.hasPermission('hr.payroll.approve'),
          canPay: widget.session.hasPermission('hr.payroll.pay'),
        );
      case 'hrAdvances':
        return HrAdvancesPage(
          searchController: _searchController,
          canReview: widget.session.hasPermission('hr.finance.adjust'),
        );
      case 'hrDiscrepancies':
        return HrDiscrepanciesPage(
          searchController: _searchController,
          canReview: widget.session.hasPermission('hr.finance.adjust'),
        );
      case 'hrSettings':
        return const HrSettingsPage();
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
      title: destination?.label ?? S.noAccessTitle,
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
    final isWide = width >= 900;
    final data = _buildLayoutData(counts);
    // الصفحات تُبنى تحت اليد نفسها: رابط «كل الطلبات» داخل بطاقة ينادي
    // `_select` هنا، فلا صفحة تملك قرارًا هو للقشرة.
    final content = AdminNavigator(onSelect: _select, child: _buildContent());

    if (isWide) {
      return AdminDesktopLayout(
        data: data,
        content: content,
        collapseSidebar:
            _selected?.immersive == true && width < _immersiveMinWidth,
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
