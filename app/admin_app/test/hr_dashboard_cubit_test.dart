import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/features/hr/dashboard/hr_dashboard_cubit.dart';
import 'package:admin_app/features/hr/dashboard/hr_dashboard_repository.dart';

class _DashboardRepository implements HrDashboardRepository {
  String? branch;
  @override
  Future<Map<String, dynamic>> load({String? branchId}) async {
    branch = branchId;
    return {
      'headcount': {'total': 4, 'active': 3},
      '_branches': [
        {'id': 'b1', 'name_en': 'North'},
      ],
    };
  }
}

class _DelayedDashboardRepository implements HrDashboardRepository {
  final requests = <String, Completer<Map<String, dynamic>>>{};

  @override
  Future<Map<String, dynamic>> load({String? branchId}) =>
      (requests[branchId!] = Completer<Map<String, dynamic>>()).future;
}

void main() {
  test('loads scoped dashboard metrics and branch choices', () async {
    final repository = _DashboardRepository();
    final cubit = HrDashboardCubit(repository: repository);
    await cubit.load(branchId: 'b1');

    expect(cubit.state.status, HrDashboardStatus.ready);
    expect(repository.branch, 'b1');
    expect(cubit.state.data['headcount']['total'], 4);
    expect(cubit.state.branches.single['id'], 'b1');
    expect(cubit.state.data.containsKey('_branches'), isFalse);
    await cubit.close();
  });

  test('ignores stale dashboard responses after changing branches', () async {
    final repository = _DelayedDashboardRepository();
    final cubit = HrDashboardCubit(repository: repository);

    final firstLoad = cubit.load(branchId: 'b1');
    final secondLoad = cubit.load(branchId: 'b2');
    repository.requests['b2']!.complete({
      'headcount': {'total': 2},
    });
    await secondLoad;

    repository.requests['b1']!.complete({
      'headcount': {'total': 9},
    });
    await firstLoad;

    expect(cubit.state.branchId, 'b2');
    expect(cubit.state.data['headcount']['total'], 2);
    await cubit.close();
  });
}
