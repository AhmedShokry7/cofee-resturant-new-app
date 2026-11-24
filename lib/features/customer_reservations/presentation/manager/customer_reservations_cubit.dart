import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/features/customer_reservations/data/repositories/customer_reservation_repository.dart';
import 'customer_reservations_state.dart';

class CustomerReservationsCubit extends Cubit<CustomerReservationsState> {
  CustomerReservationsCubit(this._repo) : super(const CustomerReservationsState());
  final CustomerReservationRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(status: CustomerReservationsStatus.loading, error: null));
    try {
      final items = await _repo.listMine();
      emit(state.copyWith(status: CustomerReservationsStatus.loaded, items: items));
    } catch (e) {
      emit(state.copyWith(status: CustomerReservationsStatus.failure, error: e.toString()));
    }
  }

  Future<void> cancel(String id) async {
    try {
      await _repo.cancel(id);
      await load();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
