import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/auth/data/models/admin_session.dart';
import 'package:admin_app/features/audit/presentation/pages/audit_log_page.dart';
import 'package:admin_app/features/banners/presentation/pages/banner_page.dart';
import 'package:admin_app/features/carts/presentation/pages/cart_page.dart';
import 'package:admin_app/features/customer_preview/presentation/pages/customer_preview_page.dart';
import 'package:admin_app/features/customers/presentation/pages/customer_page.dart';
import 'package:admin_app/features/orders/presentation/pages/order_page.dart';
import 'package:admin_app/features/payments/presentation/pages/payment_page.dart';
import 'package:admin_app/features/roles/presentation/pages/role_page.dart';
import 'package:admin_app/features/staff/presentation/pages/staff_page.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/pages/subscription_admin_page.dart';
import 'package:admin_app/features/auth/presentation/manager/admin_auth_cubit.dart';
import 'package:admin_app/features/branches/presentation/pages/branch_page.dart';
import 'package:admin_app/features/bundles/presentation/pages/bundle_page.dart';
import 'package:admin_app/features/catalog/presentation/pages/category_page.dart';
import 'package:admin_app/features/catalog/presentation/pages/product_page.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destination.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/features/shell/presentation/models/admin_shell_layout_data.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_desktop_layout.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_mobile_layout.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_sign_out_dialog.dart';
import 'package:admin_app/shared/widgets/admin_feature_placeholder.dart';

/// The frame around every admin page.
///
/// It owns the selected destination, the search state and the sign out flow,
/// then hands everything to the desktop or the mobile layout.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.session});

  final AdminSession session;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  String _selectedId = 'dashboard';

  final TextEditingController _searchTextController = TextEditingController();
  final AdminSearchController _searchController = AdminSearchController();

  @override
  void dispose() {
    _searchTextController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<AdminDestination> get _destinations => adminDestinations
      .where(
        (destination) =>
            destination.permission == null ||
            widget.session.hasPermission(destination.permission!),
      )
      .toList();

  AdminDestination get _selected {
    final destinations = _destinations;
    if (destinations.isEmpty) {
      throw StateError('No accessible destinations for this staff member.');
    }
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
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showAdminSignOutDialog(context);

    if (shouldSignOut && mounted) {
      await context.read<AdminAuthCubit>().signOut();
    }
  }

  Widget _buildContent() {
    // Every feature is listed from the database. The ones that are built show
    // their page, the rest show the shared placeholder with their tables.
    final destination = _selected;
    final page = _pageFor(destination);

    return KeyedSubtree(key: ValueKey(destination.id), child: page);
  }

  /// The page of a destination.
  ///
  /// Add a case here when a feature is built; every destination without a
  /// page keeps showing the placeholder.
  Widget _pageFor(AdminDestination destination) {
    switch (destination.id) {
      case 'products':
        return ProductPage(searchController: _searchController);
      case 'categories':
        return CategoryPage(searchController: _searchController);
      case 'branches':
        return BranchPage(
          searchController: _searchController,
          canManagePricing:
              widget.session.hasPermission('catalog.product.write') ||
              widget.session.isOwner,
        );
      case 'auditLog':
        return AuditLogPage(searchController: _searchController);
      case 'bundles':
        return BundlePage(searchController: _searchController);
      case 'payments':
        return PaymentPage(searchController: _searchController);
      case 'orders':
        return OrderPage(searchController: _searchController);
      case 'banners':
        return BannerPage(searchController: _searchController);
      case 'carts':
        return CartPage(searchController: _searchController);
      case 'customerPreview':
        return const CustomerPreviewPage();
      case 'customers':
        return CustomerPage(searchController: _searchController);
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
      default:
        return AdminFeaturePlaceholder(destination: destination);
    }
  }

  AdminShellLayoutData _buildLayoutData() {
    return AdminShellLayoutData(
      session: widget.session,
      destinations: _destinations,
      selectedId: _selected.id,
      onSelected: _select,
      onSignOut: _confirmSignOut,
      searchController: _searchController,
      searchTextController: _searchTextController,
      title: _selected.label,
      searchHint: _selected.searchHint,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The text of the panel is read while the shell builds. The shell listens
    // to the language of the panel, so a language switch re-labels the
    // sidebar, the app bar and the page right away, without a restart.
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) => _buildShell(context),
    );
  }

  Widget _buildShell(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final data = _buildLayoutData();
    final content = _buildContent();

    if (isWide) {
      return AdminDesktopLayout(data: data, content: content);
    }

    return AdminMobileLayout(data: data, content: content);
  }
}
