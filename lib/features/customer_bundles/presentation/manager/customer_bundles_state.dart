import 'package:new_coffee/features/customer_bundles/data/model/customer_bundle.dart';

enum CustomerBundlesStatus { initial, loading, loaded, failure }

class CustomerBundlesState {
  const CustomerBundlesState({
    this.status = CustomerBundlesStatus.initial,
    this.bundles = const <CustomerBundle>[],
    this.error,
  });

  final CustomerBundlesStatus status;
  final List<CustomerBundle> bundles;
  final String? error;

  CustomerBundlesState copyWith({
    CustomerBundlesStatus? status,
    List<CustomerBundle>? bundles,
    String? error,
  }) => CustomerBundlesState(
    status: status ?? this.status,
    bundles: bundles ?? this.bundles,
    error: error,
  );
}
