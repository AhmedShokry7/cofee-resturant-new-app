import 'package:flutter/material.dart';

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
