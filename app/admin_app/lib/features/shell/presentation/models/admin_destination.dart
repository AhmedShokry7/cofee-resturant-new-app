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
    this.tables = const <String>[],
    this.immersive = false,
  });

  final String id;
  final String label;
  final IconData icon;

  /// Placeholder shown in the shared app bar while this page is active.
  final String searchHint;

  final String? permission;

  /// Group this destination belongs to inside the sidebar.
  final String? section;

  /// The database tables that back this feature.
  final List<String> tables;

  /// Whether the page needs the whole width on smaller screens.
  ///
  /// A workspace page such as the counter trades the permanent sidebar for a
  /// drawer, so its secondary panel still fits beside the main one.
  final bool immersive;
}

/// Every admin feature, grouped by the area it belongs to.
///
/// The list mirrors the database: each destination points at the tables that
/// hold its data. The labels are read from [S] on every access so a language
/// switch re-labels the sidebar.
List<AdminDestination> get adminDestinations => <AdminDestination>[
  ...managementDestinations,
  ...operationsDestinations,
  ...peopleDestinations,
  ...contentDestinations,
  ...growthDestinations,
];
