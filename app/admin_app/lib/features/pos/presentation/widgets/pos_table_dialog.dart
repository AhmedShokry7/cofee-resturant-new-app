import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/pos/data/models/pos_table.dart';
import 'package:admin_app/features/pos/data/repositories/admin_pos_repository.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_cubit.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_state.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_format.dart';
import 'package:admin_app/features/tables/data/models/dining_enums.dart';
import 'package:admin_app/features/tables/data/models/dining_table.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_format.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

/// The table the cashier picked, and whether it came from seating a guest.
class PosTableChoice {
  const PosTableChoice(this.table, {this.seated = false});

  final DiningTable table;
  final bool seated;
}

/// Opens the live floor plan so the cashier picks a real table for the sale.
Future<PosTableChoice?> showPosTableDialog(
  BuildContext context, {
  required PosCubit cubit,
}) {
  return showDialog<PosTableChoice>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider<PosCubit>.value(
      value: cubit,
      child: const _PosTableDialog(),
    ),
  );
}

class _PosTableDialog extends StatefulWidget {
  const _PosTableDialog();

  @override
  State<_PosTableDialog> createState() => _PosTableDialogState();
}

class _PosTableDialogState extends State<_PosTableDialog> {
  static const _areaOrder = <DiningArea>[
    DiningArea.hall,
    DiningArea.terrace,
    DiningArea.privateRoom,
    DiningArea.other,
  ];

  final _search = TextEditingController();
  String _query = '';
  String? _seatingId;

  PosCubit get _cubit => context.read<PosCubit>();

  @override
  void initState() {
    super.initState();
    final state = _cubit.state;
    if (state.tables.isEmpty && !state.isLoadingTables) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cubit.refreshTables();
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    final normalized = value.trim();
    if (normalized == _query) return;
    setState(() => _query = normalized);
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  void _select(DiningTable table) {
    if (!table.isPosSelectable || _cubit.state.isSeating) return;
    _cubit.selectTable(table);
    Navigator.of(context).pop(PosTableChoice(table));
  }

  Future<void> _seat(DiningTable table) async {
    if (_seatingId != null || _cubit.state.isSeating) return;
    setState(() => _seatingId = table.id);
    final outcome = await _cubit.seatReservation(table);
    if (!mounted) return;
    setState(() => _seatingId = null);
    if (outcome == PosSeatOutcome.success) {
      final selected = _cubit.state.selectedTable;
      Navigator.of(context)
          .pop(PosTableChoice(selected ?? table, seated: true));
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(posSeatOutcomeMessage(outcome)),
          backgroundColor: AppColor.errorColor,
        ),
      );
    if (outcome != PosSeatOutcome.tooEarly) {
      await _cubit.refreshTables();
    }
  }

  List<DiningTable> _visibleTables(PosState state) {
    final query = _query.toLowerCase();
    if (query.isEmpty) return state.tables;
    return state.tables
        .where(
          (table) =>
              table.name.toLowerCase().contains(query) ||
              diningAreaLabel(table.area).toLowerCase().contains(query) ||
              (table.reservation?.customerName.toLowerCase().contains(query) ??
                  false) ||
              (table.activeOrder?.orderNumber.toLowerCase().contains(query) ??
                  false),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = min(640.0, size.width - 32);
    final height = min(690.0, size.height * .9);

    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        return Dialog(
          key: const Key('pos-table-dialog'),
          backgroundColor: theme.colorScheme.surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminDialogHeader(
                  title: S.posTablePickerTitle,
                  subtitle: S.posTablePickerSubtitle,
                  onClose: state.isSeating
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: AdminSearchField(
                          controller: _search,
                          onChanged: _onQueryChanged,
                          hintText: S.posTableSearchHint,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AdminToolbarButton(
                        label: S.refresh,
                        icon: HugeIcons.strokeRoundedRefresh,
                        busy: state.isLoadingTables,
                        onPressed: state.isSeating
                            ? null
                            : _cubit.refreshTables,
                      ),
                    ],
                  ),
                ),
                if (state.isLoadingTables && state.tables.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                const SizedBox(height: 8),
                if (state.isSeating)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                Expanded(child: _buildBody(context, state)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, PosState state) {
    final visible = _visibleTables(state);

    if (state.isLoadingTables && state.tables.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.tablesFailure != null && state.tables.isEmpty) {
      return AdminEmptyState(
        icon: HugeIcons.strokeRoundedAlertCircle,
        message: posTablesFailureMessage(state.tablesFailure),
        hint: S.posNoTablesHint,
        action: TextButton(
          key: const Key('pos-table-retry'),
          onPressed: state.isSeating ? null : _cubit.refreshTables,
          child: Text(S.retry),
        ),
      );
    }

    if (state.tables.isEmpty) {
      return AdminEmptyState(
        icon: HugeIcons.strokeRoundedTable01,
        message: S.posNoTables,
        hint: S.posNoTablesHint,
        action: TextButton(
          onPressed: state.isSeating ? null : _cubit.refreshTables,
          child: Text(S.refresh),
        ),
      );
    }

    if (visible.isEmpty) {
      return AdminEmptyState(
        icon: HugeIcons.strokeRoundedSearch01,
        message: S.posNoTableMatches,
        hint: S.posNoTableMatchesHint,
        action: TextButton(
          onPressed: _clearSearch,
          child: Text(S.clearFilters),
        ),
      );
    }

    final children = <Widget>[];
    for (final area in _areaOrder) {
      final tables = visible
          .where((table) => table.area == area)
          .toList(growable: false);
      if (tables.isEmpty) continue;
      children.add(
        _AreaHeader(area: area, count: tables.length, first: children.isEmpty),
      );
      for (final table in tables) {
        children.add(
          _TableTile(
            table: table,
            currencyCode: state.currencyCode,
            selected: table.id == state.selectedTableId,
            busy: state.isSeating,
            seating: _seatingId == table.id,
            onSelect: () => _select(table),
            onSeat: () => _seat(table),
          ),
        );
        children.add(const SizedBox(height: 6));
      }
    }

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 2, 12, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: children,
    );
  }
}

class _AreaHeader extends StatelessWidget {
  const _AreaHeader({
    required this.area,
    required this.count,
    required this.first,
  });

  final DiningArea area;
  final int count;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(2, first ? 4 : 12, 2, 6),
      child: Row(
        children: [
          HugeIcon(
            icon: diningAreaIcon(area),
            size: 14,
            color: adminMutedColor(theme),
          ),
          const SizedBox(width: 6),
          Text(
            diningAreaLabel(area),
            style: TextStyle(
              color: adminHeadingColor(theme),
              fontSize: AppFontSizes.size10_5,
              fontWeight: AppFontWeights.bold,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: adminTintedSurfaceColor(theme),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              localizeDigits('$count'),
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size8_5,
                fontWeight: AppFontWeights.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableTile extends StatelessWidget {
  const _TableTile({
    required this.table,
    required this.currencyCode,
    required this.selected,
    required this.busy,
    required this.seating,
    required this.onSelect,
    required this.onSeat,
  });

  final DiningTable table;
  final String currencyCode;
  final bool selected;
  final bool busy;
  final bool seating;
  final VoidCallback onSelect;
  final VoidCallback onSeat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = diningTableStatusColor(table.status);
    final selectable = table.isPosSelectable && !busy;
    final canSeat = table.canSeatGuest && !busy;

    return Material(
      key: Key('pos-table-${table.id}'),
      color: selected
          ? adminFlagBackground(
              theme,
              AppColor.adminAccent,
              AppColor.adminAccentSurface,
            )
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: selectable ? onSelect : null,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? AppColor.adminAccent.withValues(alpha: .45)
                  : adminCardBorderColor(theme),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: adminFlagBackground(
                    theme,
                    statusColor,
                    diningTableStatusSurface(table.status),
                  ),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: diningTableStatusIcon(table.status),
                  size: 17,
                  color: adminFlagForeground(theme, statusColor),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            table.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adminHeadingColor(theme),
                              fontSize: AppFontSizes.size11_5,
                              fontWeight: AppFontWeights.bold,
                              height: AppTextHeights.line1_4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        AdminStatusBadge(
                          label: diningTableStatusLabel(table.status),
                          color: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${diningAreaLabel(table.area)} • '
                      '${S.tableCapacity(table.capacity)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size9,
                        height: AppTextHeights.line1_45,
                      ),
                    ),
                    if (_contextLine(table) case final line?) ...[
                      const SizedBox(height: 2),
                      Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adminSubtleColor(theme),
                          fontSize: AppFontSizes.size9,
                          height: AppTextHeights.line1_45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (canSeat)
                TextButton(
                  key: Key('pos-table-seat-${table.id}'),
                  onPressed: onSeat,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: adminFlagForeground(
                      theme,
                      AppColor.adminAccent,
                    ),
                  ),
                  child: seating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          S.reservationSeat,
                          style: const TextStyle(
                            fontSize: AppFontSizes.size9,
                            fontWeight: AppFontWeights.bold,
                          ),
                        ),
                )
              else if (selectable)
                HugeIcon(
                  icon: selected
                      ? HugeIcons.strokeRoundedCheckmarkCircle02
                      : (Directionality.of(context) == TextDirection.rtl
                            ? HugeIcons.strokeRoundedArrowLeft01
                            : HugeIcons.strokeRoundedArrowRight01),
                  size: 16,
                  color: selected
                      ? adminFlagForeground(theme, AppColor.adminAccent)
                      : adminMutedColor(theme),
                )
              else
                HugeIcon(
                  icon: HugeIcons.strokeRoundedLock,
                  size: 15,
                  color: adminMutedColor(theme).withValues(alpha: .6),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _contextLine(DiningTable table) {
    final order = table.activeOrder;
    if (order != null) {
      final total = order.grandTotal > 0
          ? ' • ${posMoney(order.grandTotal, currencyCode)}'
          : '';
      return '${S.posTableOrderOpen(order.orderNumber)}$total';
    }
    final reservation = table.reservation;
    if (reservation != null) {
      final guest = reservation.customerName.trim();
      return '${guest.isEmpty ? S.tableGuests(reservation.partySize) : guest}'
          ' • ${diningReservationWhen(reservation)}';
    }
    if (table.status == DiningTableStatus.seated) return S.posTableSeatedHint;
    if (table.status == DiningTableStatus.available) {
      return S.tablesMetricAvailableHint;
    }
    return null;
  }
}
