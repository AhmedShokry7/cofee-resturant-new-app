import 'package:admin_app/core/navigation/admin_destination.dart';
import 'package:admin_app/features/shell/presentation/models/destinations/content_destinations.dart';
import 'package:admin_app/features/shell/presentation/models/destinations/growth_destinations.dart';
import 'package:admin_app/features/shell/presentation/models/destinations/hr_destinations.dart';
import 'package:admin_app/features/shell/presentation/models/destinations/management_destinations.dart';
import 'package:admin_app/features/shell/presentation/models/destinations/operations_destinations.dart';
import 'package:admin_app/features/shell/presentation/models/destinations/people_destinations.dart';

/// Every admin feature, grouped by the area it belongs to.
///
/// The list mirrors the database: each destination points at the tables that
/// hold its data. The labels are read from [S] on every access so a language
/// switch re-labels the sidebar.
List<AdminDestination> get adminDestinations => <AdminDestination>[
  ...managementDestinations,
  ...operationsDestinations,
  ...peopleDestinations,
  ...hrDestinations,
  ...contentDestinations,
  ...growthDestinations,
];
