import 'package:flutter/material.dart';

import 'package:admin_app/features/shell/presentation/models/destinations/content_destinations.dart';
import 'package:admin_app/features/shell/presentation/models/destinations/growth_destinations.dart';
import 'package:admin_app/features/shell/presentation/models/destinations/management_destinations.dart';
import 'package:admin_app/features/shell/presentation/models/destinations/operations_destinations.dart';
import 'package:admin_app/features/shell/presentation/models/destinations/people_destinations.dart';

class AdminDestination {
  const AdminDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.searchHint,
    this.permission,
    this.section,
    this.badge,
    this.tables = const <String>[],
    this.isImplemented = false,
  });

  final String id;
  final String label;
  final IconData icon;

  /// Placeholder shown in the shared app bar while this page is active.
  final String searchHint;

  final String? permission;

  /// Group this destination belongs to inside the sidebar.
  final String? section;

  /// Optional pill shown next to the label, for example a "new" marker.
  final String? badge;

  /// The database tables that back this feature.
  final List<String> tables;

  /// Whether the feature is already implemented in the admin app.
  final bool isImplemented;
}

/// Every admin feature, grouped by the area it belongs to.
///
/// The list mirrors the database: each destination points at the tables that
/// hold its data, and the ones that are not built yet are flagged so the
/// sidebar shows what exists and what is still missing. The labels are read
/// from [S] on every access so a language switch re-labels the sidebar.
List<AdminDestination> get adminDestinations => <AdminDestination>[
  ...managementDestinations,
  ...operationsDestinations,
  ...peopleDestinations,
  ...contentDestinations,
  ...growthDestinations,
];
