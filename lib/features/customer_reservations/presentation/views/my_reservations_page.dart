import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/customer_reservations/data/repositories/customer_reservation_repository.dart';
import 'package:new_coffee/features/customer_reservations/presentation/manager/customer_reservations_cubit.dart';
import 'package:new_coffee/features/customer_reservations/presentation/manager/customer_reservations_state.dart';
import 'package:new_coffee/features/customer_reservations/presentation/views/reservation_form_page.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';

class MyReservationsPage extends StatelessWidget {
  const MyReservationsPage({super.key});
  static const routeName = '/my-reservations';

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: BlocProvider(
        create: (_) =>
            CustomerReservationsCubit(CustomerReservationRepository())..load(),
        child: const _MyReservationsView(),
      ),
    );
  }
}

class _MyReservationsView extends StatelessWidget {
  const _MyReservationsView();

  Future<void> _openForm(BuildContext context) async {
    await Navigator.of(context).pushNamed(ReservationFormPage.routeName);
    if (context.mounted) context.read<CustomerReservationsCubit>().load();
  }

  Future<void> _confirmCancel(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.cancelReservationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(S.confirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<CustomerReservationsCubit>().cancel(id);
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'cancelled':
      case 'canceled':
        return S.cancelledStatus;
      case 'pending':
        return S.pending;
      case 'confirmed':
        return S.confirmed;
      case 'completed':
        return S.completed;
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: DesignText(
          S.myReservations,
          page: 'my_reservations',
          label: 'myReservations',
        ),
      ),
      body: BlocConsumer<CustomerReservationsCubit, CustomerReservationsState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        builder: (context, state) {
          if (state.status == CustomerReservationsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == CustomerReservationsStatus.failure) {
            return EmptyState(
              icon: Icons.event_note_outlined,
              title: S.couldNotLoadReservations,
              actionLabel: S.retry,
              onAction: () => context.read<CustomerReservationsCubit>().load(),
            );
          }
          if (state.items.isEmpty) {
            return EmptyState(
              icon: Icons.event_note_outlined,
              title: S.noReservationsYet,
              subtitle: S.reservationsHint,
              actionLabel: S.newReservation,
              onAction: () => _openForm(context),
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<CustomerReservationsCubit>().load(),
            child: ListView.separated(
              padding: AppLayout.pageBody,
              itemCount: state.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final r = state.items[i];
                final status = r.status.toLowerCase();
                final canCancel =
                    status != 'cancelled' && status != 'canceled' && status != 'completed';
                String fmtDt(DateTime d) =>
                    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
                    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
                final startStr = fmtDt(r.reservedFor.toLocal());
                final endStr = r.requestedEndAt == null ? '' : ' - ${fmtDt(r.requestedEndAt!.toLocal())}';
                return Card(
                  child: ListTile(
                    title: Text('${_statusLabel(r.status)} · ${r.partySize ?? '-'} ${S.partySize.toLowerCase()}'),
                    subtitle: Text('$startStr$endStr'),
                    trailing: canCancel
                        ? TextButton(
                            onPressed: () => _confirmCancel(context, r.id),
                            child: Text(S.cancel),
                          )
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
