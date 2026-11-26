import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/features/product_subscriptions/data/repositories/product_subscription_repository.dart';
import 'product_subscriptions_state.dart';
class ProductSubscriptionsCubit extends Cubit<ProductSubscriptionsState> {
  ProductSubscriptionsCubit(this._repo):super(const ProductSubscriptionsState());
  final ProductSubscriptionRepository _repo;
  Future<void> load() async {
    emit(state.copyWith(status:ProductSubscriptionsStatus.loading,error:null));
    try { emit(state.copyWith(status:ProductSubscriptionsStatus.loaded, items: await _repo.listMine())); }
    catch(e){ emit(state.copyWith(status:ProductSubscriptionsStatus.failure,error:e.toString())); }
  }
  Future<void> pause(String id) async { try{ await _repo.pause(id); await load(); } catch(e){ emit(state.copyWith(error:e.toString())); } }
  Future<void> resume(String id) async { try{ await _repo.resume(id); await load(); } catch(e){ emit(state.copyWith(error:e.toString())); } }
  Future<void> cancel(String id) async { try{ await _repo.cancel(id); await load(); } catch(e){ emit(state.copyWith(error:e.toString())); } }

  Future<void> skipRun(String runId) async {
    try {
      await _repo.skipRun(runId);
      await load();
    } catch (error) {
      emit(state.copyWith(error: error.toString()));
    }
  }
}
