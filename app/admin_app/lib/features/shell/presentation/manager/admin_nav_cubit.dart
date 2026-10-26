import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/shell/data/models/admin_nav_counts.dart';
import 'package:admin_app/features/shell/di/shell_dependencies.dart';
import 'package:admin_app/features/shell/domain/repositories/nav_repository.dart';
import 'package:admin_app/features/shell/domain/usecases/load_counts.dart';

/// Keeps the sidebar counters in step with the server.
///
/// The counters are polled on a slow timer instead of being part of every page
/// request, so the badge stays current while the staff work in another page.
/// A failed poll keeps the last numbers: a busy dashboard must never show a
/// zero because one request failed.
class AdminNavCubit extends Cubit<AdminNavCounts> {
  AdminNavCubit({
    NavRepository? repository,
    this.refreshInterval = const Duration(seconds: 45),
  }) : _loadCounts = LoadCountsUseCase(
         repository ?? ShellDependencies.repository,
       ),
       super(AdminNavCounts.empty);

  final LoadCountsUseCase _loadCounts;
  final Duration refreshInterval;

  Timer? _timer;
  bool _isWatching = false;
  bool _isRefreshing = false;

  /// Starts watching the counters for the destinations the caller may open.
  void start({required bool watchOrders, required bool watchKitchen}) {
    _timer?.cancel();
    _isWatching = watchOrders || watchKitchen;
    if (!_isWatching) {
      if (state != AdminNavCounts.empty) emit(AdminNavCounts.empty);
      return;
    }
    unawaited(refresh());
    _timer = Timer.periodic(refreshInterval, (_) => refresh());
  }

  Future<void> refresh() async {
    if (isClosed || !_isWatching || _isRefreshing) return;
    _isRefreshing = true;
    try {
      final counts = await _loadCounts();
      if (!isClosed && counts != state) emit(counts);
    } catch (_) {
      // The last numbers stay until the next poll succeeds.
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _timer = null;
    return super.close();
  }
}
