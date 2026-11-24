import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/customer_reservations/data/repositories/customer_reservation_repository.dart';
import '../manager/customer_reservations_cubit.dart';
import '../manager/customer_reservations_state.dart';
import 'reservation_form_page.dart';

class MyReservationsPage extends StatelessWidget {
  const MyReservationsPage({super.key});
  static const routeName = '/my-reservations';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CustomerReservationsCubit(CustomerReservationRepository())..load(),
      child: Scaffold(
        appBar: AppBar(title: Text(S.myReservations)),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
            onPressed: () async {
              final changed = await Navigator.of(context).pushNamed(ReservationFormPage.routeName);
              if (changed == true && context.mounted) context.read<CustomerReservationsCubit>().load();
            },
            child: const Icon(Icons.add),
          ),
        ),
        body: BlocBuilder<CustomerReservationsCubit, CustomerReservationsState>(
          builder: (context, state) {
            if (state.status == CustomerReservationsStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == CustomerReservationsStatus.failure) {
              return Center(child: Text(state.error ?? 'Error'));
            }
            if (state.items.isEmpty) {
              return Center(child: Text(S.myReservations));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: state.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = state.items[i];
                final canCancel = const {'pending', 'confirmed', 'approved', 'booked'}.contains(r.status);
                return Card(
                  child: ListTile(
                    title: Text('${r.reservationType.toUpperCase()} • ${r.status}'),
                    subtitle: Text('${r.reservedFor.toLocal()} • party ${r.partySize ?? '-'}'
                        '${r.cancellationReason != null ? '\nReason: ${r.cancellationReason}' : ''}'),
                    isThreeLine: r.cancellationReason != null,
                    trailing: canCancel
                        ? TextButton(
                            onPressed: () => context.read<CustomerReservationsCubit>().cancel(r.id),
                            child: const Text('Cancel'),
                          )
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
