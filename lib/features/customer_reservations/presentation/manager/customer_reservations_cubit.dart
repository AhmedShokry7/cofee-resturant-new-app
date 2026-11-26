import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/customer_reservations/data/repositories/customer_reservation_repository.dart';

import 'customer_reservations_state.dart';

class CustomerReservationsCubit extends Cubit<CustomerReservationsState> {
  CustomerReservationsCubit(this._repo)
    : super(const CustomerReservationsState());
  final CustomerReservationRepository _repo;

  Future<void> load() async {
    emit(
      state.copyWith(
        status: CustomerReservationsStatus.loading,
        clearError: true,
      ),
    );
    try {
      final reservationsFuture = _repo.listMine();
      final eventsFuture = _repo.listMyEventRequests();
      final items = await reservationsFuture;
      final events = await eventsFuture;
      emit(
        state.copyWith(
          status: CustomerReservationsStatus.loaded,
          items: items,
          eventRequests: events,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: CustomerReservationsStatus.failure,
          error: e.toString(),
        ),
      );
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

  Future<void> cancelEventRequest(String id) async {
    try {
      final cancelled = await _repo.cancelEventRequest(id);
      if (!cancelled) {
        throw StateError(S.reservationCancellationWindowClosed);
      }
      await load();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> respondToEventQuote(
    String id, {
    required bool accept,
    String? spaceId,
  }) async {
    try {
      final result = await _repo.respondToEventQuote(
        id,
        accept: accept,
        spaceId: spaceId,
      );
      if (result['ok'] != true) {
        final reason = '${result['reason'] ?? ''}';
        emit(
          state.copyWith(
            error: switch (reason) {
              'quote_expired' =>
                'انتهت صلاحية عرض السعر. اطلب عرضاً جديداً من الفرع.',
              'space_busy' || 'space_unavailable' => 'لم يعد المكان متاحاً في هذا الوقت. تواصل مع الفرع لتعديل العرض.',
              'space_capacity_changed' =>
                'تغيرت سعة المكان، تواصل مع الفرع لتعديل العرض.',
              _ => 'تعذر تنفيذ ردك على العرض حالياً.',
            },
          ),
        );
      }
      await load();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
