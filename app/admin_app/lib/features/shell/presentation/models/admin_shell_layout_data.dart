import 'package:flutter/material.dart';

import 'package:admin_app/features/auth/domain/entities/admin_session.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destination.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';

/// Everything the responsive shell layouts need to render themselves.
///
/// The shell owns this data and hands the same instance to the desktop and the
/// mobile layout, so both draw the same navigation, the same search and the
/// same sign out action.
class AdminShellLayoutData {
  const AdminShellLayoutData({
    required this.session,
    required this.destinations,
    required this.selectedId,
    required this.onSelected,
    required this.onSignOut,
    required this.searchController,
    required this.searchTextController,
    required this.title,
    required this.searchHint,
    this.badges = const <String, int>{},
  });

  final AdminSession session;

  /// The destinations the current staff member is allowed to see.
  final List<AdminDestination> destinations;

  final String selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onSignOut;

  final AdminSearchController searchController;
  final TextEditingController searchTextController;

  /// Title and search hint of the active destination.
  final String title;
  final String searchHint;

  /// Work waiting per destination, keyed by the destination id.
  final Map<String, int> badges;
}
