import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:admin_app/features/dashboard/presentation/manager/admin_dashboard_cubit.dart';
import 'package:admin_app/features/dashboard/presentation/manager/admin_dashboard_state.dart';

const _metrics = AdminDashboardMetrics(
  todayOrders: 8,
  todayRevenue: 211.71,
  activeOrders: 4,
  totalOrders: 12,
);

/// القراءة الوحيدة التي تحتاجها اللوحة، مزروعة للتحكم في نجاحها وفشلها.
/// الهدف الذي ترجعه القراءة هو الذي كُتب في المزروع لا في الكيان، فاختبار
/// «الحفظ يعيد القراءة» لا ينجح إلا إذا قرعت اللوحة القاعدة مرة ثانية.
class _FakeDashboardRepository implements DashboardRepository {
  _FakeDashboardRepository({
    this.result,
    this.targetSaver,
    double? initialTarget,
  }) : savedTarget = initialTarget;

  final Future<AdminDashboardMetrics> Function(int call)? result;
  final Future<void> Function(double?)? targetSaver;

  double? savedTarget;
  int loads = 0;

  @override
  Future<AdminDashboardMetrics> loadMetrics() {
    loads++;
    if (result != null) return result!(loads);
    return Future.value(
      AdminDashboardMetrics(
        todayOrders: 8,
        todayRevenue: 211.71,
        activeOrders: 4,
        totalOrders: 12,
        monthlyRevenueTarget: savedTarget,
      ),
    );
  }

  @override
  Future<void> saveRevenueTarget(double? value) async {
    if (targetSaver != null) return targetSaver!(value);
    savedTarget = value;
  }
}

void main() {
  group('dashboard cubit', () {
    test('load publishes what the database returned', () async {
      final cubit = AdminDashboardCubit(repository: _FakeDashboardRepository());

      await cubit.load();

      expect(cubit.state.status, AdminDashboardStatus.ready);
      expect(cubit.state.metrics.todayRevenue, 211.71);
      expect(cubit.state.errorMessage, isNull);
      await cubit.close();
    });

    test('a refused read becomes a failure the page can retry', () async {
      final cubit = AdminDashboardCubit(
        repository: _FakeDashboardRepository(
          result: (_) async => throw const PostgrestException(
            message: 'missing permission: orders.read',
            code: '42501',
          ),
        ),
      );

      await cubit.load();

      expect(cubit.state.status, AdminDashboardStatus.failure);
      expect(cubit.state.hasMetrics, isFalse);
      // السبب يصل بالعربية التي يقرأها الأدمن، ونصّ القاعدة يبقى في السجل.
      expect(cubit.state.errorMessage, S.errorNoPermission);
      expect(cubit.state.errorMessage, isNot(contains('orders.read')));
      await cubit.close();
    });

    test(
      'a second load replaces the numbers with what the base holds now',
      () async {
        final cubit = AdminDashboardCubit(
          repository: _FakeDashboardRepository(
            result: (call) async =>
                call == 1 ? _metrics : AdminDashboardMetrics.empty,
          ),
        );

        await cubit.load();
        await cubit.load();

        expect(cubit.state.metrics.totalOrders, 0);
        await cubit.close();
      },
    );

    test(
      'search and range change state without reading the base again',
      () async {
        final repository = _FakeDashboardRepository();
        final cubit = AdminDashboardCubit(repository: repository);

        await cubit.load();
        cubit.search('  Espresso ');
        cubit.setSalesRange(7);

        expect(cubit.state.query, 'espresso');
        expect(cubit.state.salesRangeDays, 7);
        expect(repository.loads, 1);
        await cubit.close();
      },
    );

    test(
      'a saved target is re-read from the base, not edited locally',
      () async {
        final repository = _FakeDashboardRepository(initialTarget: 1200);
        final cubit = AdminDashboardCubit(repository: repository);
        await cubit.load();

        final saved = await cubit.saveRevenueTarget(1500);

        expect(saved, isTrue);
        expect(repository.savedTarget, 1500);
        expect(cubit.state.targetStatus, AdminDashboardTargetStatus.idle);
        // الرقم المعروض جاء من قراءة ثانية للقاعدة، لا من تعديل الحالة المحلية.
        expect(cubit.state.metrics.monthlyRevenueTarget, 1500);
        expect(repository.loads, 2);
        await cubit.close();
      },
    );

    test(
      'a refused write reports itself and leaves the board on screen',
      () async {
        final cubit = AdminDashboardCubit(
          repository: _FakeDashboardRepository(
            targetSaver: (_) async => throw const PostgrestException(
              message: 'missing permission: settings.write',
              code: '42501',
            ),
          ),
        );
        await cubit.load();

        final saved = await cubit.saveRevenueTarget(900);

        expect(saved, isFalse);
        expect(cubit.state.targetStatus, AdminDashboardTargetStatus.failure);
        expect(cubit.state.targetError, S.errorNoPermission);
        expect(cubit.state.targetError, isNot(contains('settings.write')));
        expect(cubit.state.status, AdminDashboardStatus.ready);
        expect(cubit.state.metrics.totalOrders, 12);
        await cubit.close();
      },
    );
  });
}
