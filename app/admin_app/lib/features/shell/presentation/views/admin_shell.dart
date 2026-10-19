import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/auth/data/models/admin_session.dart';
import 'package:admin_app/features/auth/presentation/manager/admin_auth_cubit.dart';
import 'package:admin_app/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destination.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_sidebar.dart';
import 'package:admin_app/shared/widgets/coming_soon_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.session});

  final AdminSession session;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  String _selectedId = 'dashboard';

  List<AdminDestination> get _destinations => adminDestinations
      .where((destination) =>
          destination.permission == null ||
          widget.session.hasPermission(destination.permission!))
      .toList();

  AdminDestination get _selected {
    final destinations = _destinations;
    for (final destination in destinations) {
      if (destination.id == _selectedId) return destination;
    }
    return destinations.first;
  }

  void _select(String id) {
    setState(() => _selectedId = id);
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true && mounted) {
      await context.read<AdminAuthCubit>().signOut();
    }
  }

  Widget _buildContent() {
    if (_selected.id == 'dashboard') {
      return DashboardPage(
        key: const ValueKey('dashboard'),
        session: widget.session,
      );
    }
    return ComingSoonPage(
      key: ValueKey(_selected.id),
      title: _selected.label,
      icon: _selected.icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final content = _buildContent();

    final sidebar = AdminSidebar(
      session: widget.session,
      destinations: _destinations,
      selectedId: _selected.id,
      onSelected: _select,
      onSignOut: _confirmSignOut,
    );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            sidebar,
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_selected.label),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout, color: AppColor.errorColor),
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      drawer: Drawer(
        child: AdminSidebar(
          session: widget.session,
          destinations: _destinations,
          selectedId: _selected.id,
          onSelected: (id) {
            _select(id);
            Navigator.of(context).pop();
          },
          onSignOut: () {
            Navigator.of(context).pop();
            _confirmSignOut();
          },
        ),
      ),
      body: content,
    );
  }
}
