import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/tables/data/models/dining_enums.dart';
import 'package:admin_app/features/tables/data/models/dining_reservation.dart';
import 'package:admin_app/features/tables/data/models/dining_table.dart';
import 'package:admin_app/features/tables/data/repositories/dining_tables_repository.dart';
import 'package:admin_app/features/tables/presentation/manager/dining_tables_cubit.dart';
import 'package:admin_app/features/tables/presentation/manager/dining_tables_state.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_actions.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_format.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_reservation_dialog.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_table_dialog.dart';
import 'package:admin_app/features/tables/presentation/widgets/tables_page_body.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class TablesPage extends StatefulWidget {
  const TablesPage({super.key, this.cubit, this.canManage = false});

  static const String routeName = '/tables';

  final DiningTablesCubit? cubit;
  final bool canManage;

  @override
  State<TablesPage> createState() => _TablesPageState();
}

class _TablesPageState extends State<TablesPage> {
  late final DiningTablesCubit _cubit;
  late final bool _ownsCubit;
  final Set<String> _pendingTables = <String>{};
  final Set<String> _pendingReservations = <String>{};

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? DiningTablesCubit();
    if (_ownsCubit) _cubit.load();
  }

  @override
  void dispose() {
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  Future<void> _addTable() async {
    if (!widget.canManage) return;
    final saved = await showDiningTableDialog(
      context,
      cubit: _cubit,
      branchId: _cubit.state.branchId,
    );
    if (saved == true && mounted) _showMessage(S.tableCreated);
  }

  Future<void> _editTable(DiningTable table) async {
    if (!widget.canManage) return;
    final saved = await showDiningTableDialog(
      context,
      cubit: _cubit,
      table: table,
    );
    if (saved == true && mounted) _showMessage(S.tableUpdated);
  }

  Future<void> _addReservation() async {
    if (!widget.canManage || _cubit.state.tables.isEmpty) return;
    final saved = await showDiningReservationDialog(
      context,
      cubit: _cubit,
      tables: _cubit.state.tables,
    );
    if (saved == true && mounted) _showMessage(S.reservationCreated);
  }

  Future<void> _bookTable(DiningTable table) async {
    if (!widget.canManage) return;
    final saved = await showDiningReservationDialog(
      context,
      cubit: _cubit,
      tables: _cubit.state.tables,
      initialTable: table,
    );
    if (saved == true && mounted) _showMessage(S.reservationCreated);
  }

  Future<void> _openReservation(DiningTable table) async {
    if (!widget.canManage) return;
    final reservation = _reservationFor(table);
    if (reservation == null) {
      await _bookTable(table);
      return;
    }
    final saved = await showDiningReservationDialog(
      context,
      cubit: _cubit,
      tables: _cubit.state.tables,
      reservation: reservation,
    );
    if (saved == true && mounted) _showMessage(S.reservationUpdated);
  }

  Future<void> _editReservation(DiningReservation reservation) async {
    if (!widget.canManage) return;
    final saved = await showDiningReservationDialog(
      context,
      cubit: _cubit,
      tables: _cubit.state.tables,
      reservation: reservation,
    );
    if (saved == true && mounted) _showMessage(S.reservationUpdated);
  }

  DiningReservation? _reservationFor(DiningTable table) {
    if (table.reservation != null) return table.reservation;
    if (table.nextReservation != null) return table.nextReservation;
    for (final reservation in _cubit.state.reservations) {
      if (reservation.tableId == table.id && reservation.isOpen) {
        return reservation;
      }
    }
    return null;
  }

  Future<void> _toggleTable(DiningTable table) async {
    if (!widget.canManage || _pendingTables.contains(table.id)) return;
    if (table.isActive) {
      final confirmed = await confirmDiningTableDeactivation(context, table);
      if (!confirmed || !mounted) return;
    }
    _pendingTables.add(table.id);
    try {
      final outcome = await _cubit.setTableActive(table.id, !table.isActive);
      if (!mounted) return;
      if (outcome == DiningTableMutationOutcome.success) {
        _showMessage(table.isActive ? S.tableDeactivated : S.tableActivated);
      } else {
        _showMessage(diningTableMutationErrorMessage(outcome), error: true);
      }
    } finally {
      _pendingTables.remove(table.id);
    }
  }

  Future<void> _deleteTable(DiningTable table) async {
    if (!widget.canManage || _pendingTables.contains(table.id)) return;
    final confirmed = await confirmDiningTableDeletion(context, table);
    if (!confirmed || !mounted) return;
    _pendingTables.add(table.id);
    try {
      final outcome = await _cubit.deleteTable(table.id);
      if (!mounted) return;
      if (outcome == DiningTableMutationOutcome.success) {
        _showMessage(S.tableDeleted);
      } else {
        _showMessage(diningTableMutationErrorMessage(outcome), error: true);
      }
    } finally {
      _pendingTables.remove(table.id);
    }
  }

  Future<void> _setReservationStatus(
    DiningReservation reservation,
    DiningReservationStatus status,
  ) async {
    if (!widget.canManage || _pendingReservations.contains(reservation.id)) {
      return;
    }
    final confirmed = await _confirmStatus(reservation, status);
    if (!confirmed || !mounted) return;

    _pendingReservations.add(reservation.id);
    try {
      final outcome = await _cubit.setReservationStatus(reservation.id, status);
      if (!mounted) return;
      if (outcome == DiningReservationStatusOutcome.success) {
        _showMessage(switch (status) {
          DiningReservationStatus.seated => S.reservationSeatedToast,
          DiningReservationStatus.completed => S.reservationCompletedToast,
          DiningReservationStatus.cancelled => S.reservationCancelledToast,
          DiningReservationStatus.noShow => S.reservationNoShowToast,
          DiningReservationStatus.confirmed => '',
        });
      } else {
        _showMessage(diningReservationStatusErrorMessage(outcome), error: true);
      }
    } finally {
      _pendingReservations.remove(reservation.id);
    }
  }

  Future<bool> _confirmStatus(
    DiningReservation reservation,
    DiningReservationStatus status,
  ) async {
    switch (status) {
      case DiningReservationStatus.seated:
        final start = reservation.reservedFor;
        if (start != null &&
            start.isAfter(DateTime.now().add(const Duration(hours: 2)))) {
          _showMessage(S.reservationSeatTooEarly, error: true);
          return false;
        }
        return confirmDiningSeating(context, reservation);
      case DiningReservationStatus.completed:
        return confirmDiningCompletion(context, reservation);
      case DiningReservationStatus.cancelled:
        return confirmDiningCancellation(context, reservation);
      case DiningReservationStatus.noShow:
        return confirmDiningNoShow(context, reservation);
      case DiningReservationStatus.confirmed:
        return false;
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (message.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColor.errorColor : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DiningTablesCubit>.value(
      value: _cubit,
      child: BlocBuilder<DiningTablesCubit, DiningTablesState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasData) {
            return const AdminLoadingView();
          }
          if (state.isFailure && !state.hasData) {
            return AdminFailureView(
              message: diningLoadErrorMessage(state.errorMessage),
              onRetry: _cubit.load,
            );
          }
          return TablesPageBody(
            state: state,
            canManage: widget.canManage,
            errorMessage: state.errorMessage == null
                ? null
                : diningLoadErrorMessage(state.errorMessage),
            onSearchChanged: _cubit.updateSearch,
            onAreaChanged: _cubit.setArea,
            onBranchChanged: _cubit.setBranch,
            onViewChanged: _cubit.setView,
            onClearFilters: _cubit.clearFilters,
            onRefresh: _cubit.refresh,
            onAddTable: _addTable,
            onAddReservation: _addReservation,
            onEditTable: _editTable,
            onBookTable: _bookTable,
            onOpenReservation: _openReservation,
            onToggleTable: _toggleTable,
            onDeleteTable: _deleteTable,
            onEditReservation: _editReservation,
            onSeatReservation: (reservation) => _setReservationStatus(
              reservation,
              DiningReservationStatus.seated,
            ),
            onCompleteReservation: (reservation) => _setReservationStatus(
              reservation,
              DiningReservationStatus.completed,
            ),
            onCancelReservation: (reservation) => _setReservationStatus(
              reservation,
              DiningReservationStatus.cancelled,
            ),
            onNoShowReservation: (reservation) => _setReservationStatus(
              reservation,
              DiningReservationStatus.noShow,
            ),
          );
        },
      ),
    );
  }
}
