import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/customers/data/models/admin_customer.dart';
import 'package:admin_app/features/customers/data/models/admin_customer_metrics.dart';
import 'package:admin_app/features/customers/data/repositories/admin_customer_repository.dart';
import 'package:admin_app/features/customers/presentation/manager/admin_customer_cubit.dart';
import 'package:admin_app/features/customers/presentation/manager/admin_customer_state.dart';

class _FakeCustomerRepository extends AdminCustomerRepository {
  _FakeCustomerRepository({
    this.customers = const <AdminCustomer>[],
    this.metrics = AdminCustomerMetrics.empty,
  });

  List<AdminCustomer> customers;
  AdminCustomerMetrics metrics;
  Object? failure;

  @override
  Future<List<AdminCustomer>> loadCustomers() async {
    if (failure != null) throw failure!;
    return customers;
  }

  @override
  Future<AdminCustomerMetrics> loadMetrics() async {
    if (failure != null) throw failure!;
    return metrics;
  }
}

void main() {
  test('load emits the customers and the metrics of the repository', () async {
    const customer = AdminCustomer(id: 'c1', fullName: 'Customer One');
    const metrics = AdminCustomerMetrics(
      totalCustomers: 1,
      newCustomers: 1,
      currentBuyers: 1,
      currentSpent: 80,
    );
    final repository = _FakeCustomerRepository(
      customers: const <AdminCustomer>[customer],
      metrics: metrics,
    );
    final cubit = AdminCustomerCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, AdminCustomerStatus.ready);
    expect(cubit.state.customers, const <AdminCustomer>[customer]);
    expect(cubit.state.metrics, same(metrics));
    expect(cubit.state.errorMessage, isNull);
  });

  test('a failed reload keeps the customers already on screen', () async {
    const customer = AdminCustomer(id: 'c1', fullName: 'Customer One');
    final repository = _FakeCustomerRepository(
      customers: const <AdminCustomer>[customer],
    );
    final cubit = AdminCustomerCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    repository.failure = StateError('offline');
    await cubit.load();

    expect(cubit.state.status, AdminCustomerStatus.failure);
    expect(cubit.state.customers, const <AdminCustomer>[customer]);
    expect(cubit.state.errorMessage, contains('offline'));
  });
}
