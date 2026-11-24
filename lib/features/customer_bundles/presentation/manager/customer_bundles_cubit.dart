import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/customer_bundles/data/model/customer_bundle.dart';
import 'package:new_coffee/features/customer_bundles/data/repositories/customer_bundle_repository.dart';
import 'package:new_coffee/features/customer_bundles/presentation/manager/customer_bundles_state.dart';

class CustomerBundlesCubit extends Cubit<CustomerBundlesState> {
  CustomerBundlesCubit(this._repo) : super(const CustomerBundlesState());

  final CustomerBundleRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(status: CustomerBundlesStatus.loading, error: null));
    try {
      final bundles = await _repo.listMyBundles();
      emit(state.copyWith(status: CustomerBundlesStatus.loaded, bundles: bundles));
    } catch (e) {
      emit(state.copyWith(status: CustomerBundlesStatus.failure, error: e.toString()));
    }
  }

  Future<void> delete(String id) async {
    try {
      await _repo.deleteBundle(id);
      await load();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> duplicate(String id) async {
    try {
      await _repo.duplicateBundle(id);
      await load();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> toggleFavorite(CustomerBundle b) async {
    try {
      await _repo.updateBundle(id: b.id, name: b.name, description: b.description, isFavorite: !b.isFavorite);
      await load();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
