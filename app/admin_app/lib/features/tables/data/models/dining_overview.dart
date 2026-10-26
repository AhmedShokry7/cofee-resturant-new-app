import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/tables/data/models/dining_reservation.dart';
import 'package:admin_app/features/tables/data/models/dining_table.dart';

class DiningBranch {
  const DiningBranch({
    required this.id,
    this.code = '',
    this.nameAr = '',
    this.nameEn = '',
    this.isActive = true,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final bool isActive;

  String nameFor(AppLanguage language) {
    final primary = language.isArabic ? nameAr : nameEn;
    final fallback = language.isArabic ? nameEn : nameAr;
    final name = primary.trim();
    return name.isNotEmpty ? name : fallback.trim();
  }

  factory DiningBranch.fromJson(Map<String, dynamic> json) {
    return DiningBranch(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? ''}',
      isActive: json['is_active'] != false,
    );
  }
}

class DiningMetrics {
  const DiningMetrics({
    this.tables = 0,
    this.available = 0,
    this.occupied = 0,
    this.reserved = 0,
    this.reservationsToday = 0,
    this.upcoming = 0,
  });

  final int tables;
  final int available;
  final int occupied;

  /// Reserved and seated tables together.
  final int reserved;
  final int reservationsToday;
  final int upcoming;

  factory DiningMetrics.fromJson(Map<String, dynamic> json) {
    return DiningMetrics(
      tables: _integer(json['tables']),
      available: _integer(json['available']),
      occupied: _integer(json['occupied']),
      reserved: _integer(json['reserved']),
      reservationsToday: _integer(json['reservations_today']),
      upcoming: _integer(json['upcoming']),
    );
  }
}

/// The whole floor of one branch: tables, live statuses and bookings.
class DiningOverview {
  const DiningOverview({
    this.branchId,
    this.branches = const <DiningBranch>[],
    this.tables = const <DiningTable>[],
    this.reservations = const <DiningReservation>[],
    this.metrics = const DiningMetrics(),
  });

  final String? branchId;
  final List<DiningBranch> branches;
  final List<DiningTable> tables;
  final List<DiningReservation> reservations;
  final DiningMetrics metrics;

  bool get hasBranches => branches.isNotEmpty;

  factory DiningOverview.fromJson(Map<String, dynamic> json) {
    final branchId = '${json['branch_id'] ?? ''}'.trim();
    return DiningOverview(
      branchId: branchId.isEmpty ? null : branchId,
      branches: _rows(json['branches'], DiningBranch.fromJson),
      tables: _rows(json['tables'], DiningTable.fromJson),
      reservations: _rows(
        json['reservations'],
        (row) => DiningReservation.fromJson(row),
      ),
      metrics: json['metrics'] is Map
          ? DiningMetrics.fromJson(
              Map<String, dynamic>.from(json['metrics'] as Map),
            )
          : const DiningMetrics(),
    );
  }
}

List<T> _rows<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => parse(Map<String, dynamic>.from(row)))
      .toList(growable: false);
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}
