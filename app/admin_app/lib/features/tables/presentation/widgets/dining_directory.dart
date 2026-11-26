import 'package:material_ui/material_ui.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/dining_enums.dart';
import 'package:admin_app/core/models/dining_reservation.dart';
import 'package:admin_app/core/models/dining_table.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/dining_format.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/tables/domain/entities/dining_overview.dart';
import 'package:admin_app/features/tables/presentation/manager/dining_tables_state.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_reservation_panel.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_table_card.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_create_button.dart';

/// The floor plan and its booking rail, split on wide screens and switched
/// between two views on compact ones.
class DiningDirectory extends StatefulWidget {
  const DiningDirectory({
    super.key,
    required this.tables,
    required this.allTables,
    required this.openReservations,
    required this.closedReservations,
    required this.branches,
    required this.branchId,
    required this.search,
    required this.area,
    required this.view,
    required this.canManage,
    required this.isRefreshing,
    required this.hasActiveFilters,
    required this.onSearchChanged,
    required this.onAreaChanged,
    required this.onBranchChanged,
    required this.onViewChanged,
    required this.onClearFilters,
    required this.onRefresh,
    required this.onAddTable,
    required this.onAddReservation,
    required this.onEditTable,
    required this.onBookTable,
    required this.onOpenReservation,
    required this.onToggleTable,
    required this.onDeleteTable,
    required this.onMoveTable,
    required this.onEditReservation,
    required this.onSeatReservation,
    required this.onCompleteReservation,
    required this.onCancelReservation,
    required this.onNoShowReservation,
  });

  final List<DiningTable> tables;
  final List<DiningTable> allTables;
  final List<DiningReservation> openReservations;
  final List<DiningReservation> closedReservations;
  final List<DiningBranch> branches;
  final String? branchId;
  final String search;
  final DiningArea? area;
  final DiningView view;
  final bool canManage;
  final bool isRefreshing;
  final bool hasActiveFilters;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DiningArea?> onAreaChanged;
  final ValueChanged<String> onBranchChanged;
  final ValueChanged<DiningView> onViewChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onRefresh;
  final VoidCallback onAddTable;
  final VoidCallback onAddReservation;
  final ValueChanged<DiningTable> onEditTable;
  final ValueChanged<DiningTable> onBookTable;
  final ValueChanged<DiningTable> onOpenReservation;
  final ValueChanged<DiningTable> onToggleTable;
  final ValueChanged<DiningTable> onDeleteTable;
  final Future<void> Function(DiningTable table, double x, double y) onMoveTable;
  final ValueChanged<DiningReservation> onEditReservation;
  final ValueChanged<DiningReservation> onSeatReservation;
  final ValueChanged<DiningReservation> onCompleteReservation;
  final ValueChanged<DiningReservation> onCancelReservation;
  final ValueChanged<DiningReservation> onNoShowReservation;

  @override
  State<DiningDirectory> createState() => _DiningDirectoryState();
}

class _DiningDirectoryState extends State<DiningDirectory> {
  static const double _splitBreakpoint = 980;
  bool _showFloorPlan = false;

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(DiningDirectory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search &&
        _searchController.text.trim() != widget.search) {
      _searchController.value = TextEditingValue(
        text: widget.search,
        selection: TextSelection.collapsed(offset: widget.search.length),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _splitBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AdminDirectoryPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _toolbar(compact: false),
                      const SizedBox(height: AppSizes.px12),
                      Expanded(child: _tablesContent()),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.px14),
              SizedBox(
                width: 328,
                child: AdminDirectoryPanel(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: _reservationPane(),
                ),
              ),
            ],
          );
        }

        return AdminDirectoryPanel(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _toolbar(compact: true),
              const SizedBox(height: AppSizes.px10),
              _ViewSwitch(
                value: widget.view,
                counts: [
                  widget.allTables.length,
                  widget.openReservations.length,
                ],
                onChanged: widget.onViewChanged,
              ),
              const SizedBox(height: AppSizes.px10),
              Expanded(
                child: widget.view == DiningView.tables
                    ? _tablesContent()
                    : _reservationPane(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _toolbar({required bool compact}) {
    final selectedBranch = _selectedBranch();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AdminSearchField(
                controller: _searchController,
                onChanged: widget.onSearchChanged,
                hintText: S.tablesSearchHint,
              ),
            ),
            if (widget.branches.isNotEmpty) ...[
              const SizedBox(width: AppSizes.px8),
              _BranchChip(
                name:
                    selectedBranch?.nameFor(AppLocale.instance.language) ??
                    S.tablesFilterBranch,
                icon: AppIcons.store01,
                branches: widget.branches,
                selectedId: widget.branchId,
                enabled: widget.branches.length > 1,
                onChanged: widget.onBranchChanged,
              ),
            ],
            const SizedBox(width: AppSizes.px8),
            _RefreshButton(
              busy: widget.isRefreshing,
              onPressed: widget.onRefresh,
            ),
          ],
        ),
        const SizedBox(height: AppSizes.px10),
        _AreaChips(
          allTables: widget.allTables,
          selected: widget.area,
          onChanged: widget.onAreaChanged,
        ),
        if (widget.allTables.isNotEmpty) ...[
          const SizedBox(height: AppSizes.px8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: AppIcon(AppIcons.table01, size: 14),
                  label: Text('بطاقات الأماكن'),
                ),
                ButtonSegment(
                  value: true,
                  icon: AppIcon(AppIcons.mapPin, size: 14),
                  label: Text('مخطط 2D'),
                ),
              ],
              selected: {_showFloorPlan},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => _showFloorPlan = value.first),
            ),
          ),
        ],
        if (widget.hasActiveFilters) ...[
          const SizedBox(height: AppSizes.px6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: widget.onClearFilters,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const AppIcon(
                AppIcons.cancel01,
                size: 13,
                color: AppColor.adminMuted,
              ),
              label: Text(
                S.clearFilters,
                style: TextStyle(
                  fontSize: AppFontSizes.size9_5,
                  color: adminMutedColor(Theme.of(context)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  DiningBranch? _selectedBranch() {
    for (final branch in widget.branches) {
      if (branch.id == widget.branchId) return branch;
    }
    return null;
  }

  Widget _tablesContent() {
    if (_showFloorPlan) {
      if (widget.tables.isEmpty) {
        return AdminEmptyState(
          icon: AppIcons.search01,
          message: S.tablesNoMatches,
          hint: S.tablesNoMatchesHint,
          action: TextButton(
            onPressed: widget.onClearFilters,
            child: Text(S.clearFilters),
          ),
        );
      }
      return _DiningFloorPlan(
        tables: widget.tables,
        canManage: widget.canManage,
        onMove: widget.onMoveTable,
        onEdit: widget.onEditTable,
      );
    }
    if (widget.allTables.isEmpty) {
      return AdminEmptyState(
        icon: AppIcons.table01,
        message: S.tablesEmptyTitle,
        hint: S.tablesEmptyHint,
        action: widget.canManage
            ? AdminCreateButton(label: S.addTable, onPressed: widget.onAddTable)
            : null,
      );
    }
    if (widget.tables.isEmpty) {
      return AdminEmptyState(
        icon: AppIcons.search01,
        message: S.tablesNoMatches,
        hint: S.tablesNoMatchesHint,
        action: TextButton(
          onPressed: widget.onClearFilters,
          child: Text(S.clearFilters),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 780
            ? 3
            : width >= 520
            ? 2
            : 1;
        return GridView.builder(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 11,
            mainAxisSpacing: 11,
            mainAxisExtent: columns == 1 ? 192 : 204,
          ),
          itemCount: widget.tables.length,
          itemBuilder: (context, index) {
            final table = widget.tables[index];
            return DiningTableCard(
              table: table,
              canManage: widget.canManage,
              onEdit: () => widget.onEditTable(table),
              onBook: () => widget.onBookTable(table),
              onOpenReservation: () => widget.onOpenReservation(table),
              onToggleActive: () => widget.onToggleTable(table),
              onDelete: () => widget.onDeleteTable(table),
            );
          },
        );
      },
    );
  }

  Widget _reservationPane() {
    final hasTables = widget.allTables.isNotEmpty;
    return DiningReservationPanel(
      open: widget.openReservations,
      closed: widget.closedReservations,
      canManage: widget.canManage,
      onAdd: hasTables ? widget.onAddReservation : null,
      onEdit: widget.onEditReservation,
      onSeat: widget.onSeatReservation,
      onComplete: widget.onCompleteReservation,
      onCancel: widget.onCancelReservation,
      onNoShow: widget.onNoShowReservation,
      emptyMessage: widget.hasActiveFilters
          ? S.tablesReservationsNoMatches
          : S.tablesReservationsEmpty,
      emptyHint: widget.hasActiveFilters
          ? S.tablesReservationsNoMatchesHint
          : S.tablesReservationsEmptyHint,
    );
  }
}

class _DiningFloorPlan extends StatefulWidget {
  const _DiningFloorPlan({
    required this.tables,
    required this.canManage,
    required this.onMove,
    required this.onEdit,
  });

  final List<DiningTable> tables;
  final bool canManage;
  final Future<void> Function(DiningTable, double, double) onMove;
  final ValueChanged<DiningTable> onEdit;

  @override
  State<_DiningFloorPlan> createState() => _DiningFloorPlanState();
}

class _DiningFloorPlanState extends State<_DiningFloorPlan> {
  final Map<String, Offset> _positions = {};

  @override
  void didUpdateWidget(covariant _DiningFloorPlan oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final table in widget.tables) {
      if (table.layoutX != null && table.layoutY != null) {
        _positions[table.id] = Offset(table.layoutX!, table.layoutY!);
      }
    }
    final ids = widget.tables.map((table) => table.id).toSet();
    _positions.removeWhere((id, _) => !ids.contains(id));
  }

  Offset _position(DiningTable table, int index) => _positions[table.id] ??
      Offset(
        .07 + (index % 4) * .28,
        (.22 + (index ~/ 4) * .2).clamp(.22, .86).toDouble(),
      );

  void _move(DiningTable table, Offset delta, double maxLeft, double maxTop) {
    final index = widget.tables.indexWhere((item) => item.id == table.id);
    final current = _position(table, index < 0 ? 0 : index);
    setState(() {
      _positions[table.id] = Offset(
        (current.dx + delta.dx / maxLeft).clamp(0, 1).toDouble(),
        (current.dy + delta.dy / maxTop).clamp(0, 1).toDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const mapHeight = 480.0;
        const nodeWidth = 126.0;
        const nodeHeight = 78.0;
        final width = constraints.maxWidth;
        final maxLeft = (width - nodeWidth).clamp(1, double.infinity).toDouble();
        const maxTop = mapHeight - nodeHeight;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
              child: Row(
                children: [
                  const AppIcon(AppIcons.mapPin, size: 16),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      widget.canManage
                          ? 'اسحب كل مكان لتحديد موقعه على مخطط المقهى.'
                          : 'مخطط أماكن الجلوس في المقهى.',
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size10,
                      ),
                    ),
                  ),
                  Text('${widget.tables.length} مكان'),
                ],
              ),
            ),
            Container(
              height: mapHeight,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: adminCardBorderColor(theme)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _FloorGridPainter(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
                  ))),
                  PositionedDirectional(
                    top: 16,
                    start: 18,
                    end: 18,
                    child: Container(
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: adminTintedSurfaceColor(theme),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: adminControlBorderColor(theme)),
                      ),
                      child: const Text('منطقة التحضير والكاشير'),
                    ),
                  ),
                  PositionedDirectional(
                    bottom: 8,
                    start: 16,
                    end: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppIcon(AppIcons.door01, size: 15),
                        const SizedBox(width: 6),
                        Text('المدخل', style: TextStyle(color: adminMutedColor(theme))),
                      ],
                    ),
                  ),
                  for (var index = 0; index < widget.tables.length; index++)
                    _tableNode(
                      context,
                      widget.tables[index],
                      _position(widget.tables[index], index),
                      index,
                      maxLeft,
                      maxTop,
                      nodeWidth,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tableNode(
    BuildContext context,
    DiningTable table,
    Offset position,
    int index,
    double maxLeft,
    double maxTop,
    double nodeWidth,
  ) {
    final theme = Theme.of(context);
    final busy = table.status == DiningTableStatus.occupied ||
        table.status == DiningTableStatus.reserved;
    final accent = busy ? AppColor.adminWarning : AppColor.adminAccent;
    return Positioned(
      left: position.dx * maxLeft,
      top: position.dy * maxTop,
      child: GestureDetector(
        onPanUpdate: widget.canManage
            ? (details) => _move(table, details.delta, maxLeft, maxTop)
            : null,
        onPanEnd: widget.canManage
            ? (_) {
                final saved = _position(table, index);
                widget.onMove(table, saved.dx, saved.dy);
              }
            : null,
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(
            table.area == DiningArea.privateRoom ? 14 : 28,
          ),
          elevation: 2,
          child: InkWell(
            onTap: widget.canManage ? () => widget.onEdit(table) : null,
            borderRadius: BorderRadius.circular(
              table.area == DiningArea.privateRoom ? 14 : 28,
            ),
            child: Container(
              width: nodeWidth,
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  table.area == DiningArea.privateRoom ? 14 : 28,
                ),
                border: Border.all(color: accent.withValues(alpha: .7), width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(
                    table.area == DiningArea.privateRoom
                        ? AppIcons.door01
                        : AppIcons.table01,
                    size: 18,
                    color: accent,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    table.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminHeadingColor(theme),
                      fontSize: AppFontSizes.size9_5,
                      fontWeight: AppFontWeights.bold,
                    ),
                  ),
                  Text(
                    '${table.capacity} مقعد',
                    style: TextStyle(
                      color: adminMutedColor(theme),
                      fontSize: AppFontSizes.size8_5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloorGridPainter extends CustomPainter {
  const _FloorGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = .6;
    for (var x = 24.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 24.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloorGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({
    required this.value,
    required this.counts,
    required this.onChanged,
  });

  final DiningView value;
  final List<int> counts;
  final ValueChanged<DiningView> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segment(
              context,
              view: DiningView.tables,
              label: S.tablesViewTables,
              count: counts.isNotEmpty ? counts.first : 0,
              icon: AppIcons.table01,
              key: const Key('dining-view-tables'),
            ),
          ),
          const SizedBox(width: AppSizes.px4),
          Expanded(
            child: _segment(
              context,
              view: DiningView.reservations,
              label: S.tablesViewReservations,
              count: counts.length > 1 ? counts[1] : 0,
              icon: AppIcons.calendar01,
              key: const Key('dining-view-reservations'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required DiningView view,
    required String label,
    required int count,
    required IconData icon,
    required Key key,
  }) {
    final theme = Theme.of(context);
    final selected = view == value;
    final foreground = selected
        ? adminHeadingColor(theme)
        : adminMutedColor(theme);
    return Material(
      key: key,
      color: selected ? theme.colorScheme.surface : AppColor.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: selected ? null : () => onChanged(view),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(
                icon,
                size: 14,
                color: selected ? AppColor.adminAccent : foreground,
              ),
              const SizedBox(width: AppSizes.px6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: AppFontSizes.size10,
                    fontWeight: selected
                        ? AppFontWeights.bold
                        : AppFontWeights.medium,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: AppSizes.px4),
                Text(
                  localizeDigits('$count'),
                  style: TextStyle(
                    color: foreground.withValues(alpha: .8),
                    fontSize: AppFontSizes.size8_5,
                    fontWeight: AppFontWeights.semiBold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaChips extends StatelessWidget {
  const _AreaChips({
    required this.allTables,
    required this.selected,
    required this.onChanged,
  });

  final List<DiningTable> allTables;
  final DiningArea? selected;
  final ValueChanged<DiningArea?> onChanged;

  int _count(DiningArea? area) => area == null
      ? allTables.length
      : allTables.where((table) => table.area == area).length;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _AreaChip(
          label: S.tablesAreaAll,
          count: _count(null),
          icon: AppIcons.menu01,
          selected: selected == null,
          onTap: () => onChanged(null),
        ),
        for (final area in DiningArea.values)
          _AreaChip(
            label: diningAreaLabel(area),
            count: _count(area),
            icon: diningAreaIcon(area),
            selected: selected == area,
            onTap: () => onChanged(area),
          ),
      ],
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? adminFlagForeground(theme, AppColor.adminAccent)
        : adminMutedColor(theme);
    return Material(
      color: selected
          ? adminFlagBackground(
              theme,
              AppColor.adminAccent,
              AppColor.adminAccentSurface,
            )
          : AppColor.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected
                  ? AppColor.adminAccent.withValues(alpha: .4)
                  : adminControlBorderColor(theme),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                icon,
                size: 13,
                color: selected ? AppColor.adminAccent : foreground,
              ),
              const SizedBox(width: AppSizes.px6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: AppFontSizes.size9_5,
                  fontWeight: selected
                      ? AppFontWeights.bold
                      : AppFontWeights.medium,
                  height: AppTextHeights.line1_5,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: AppSizes.px4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColor.adminAccent.withValues(alpha: .14)
                        : adminTintedSurfaceColor(theme),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    localizeDigits('$count'),
                    style: TextStyle(
                      color: foreground,
                      fontSize: AppFontSizes.size8,
                      fontWeight: AppFontWeights.semiBold,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({
    required this.name,
    required this.icon,
    required this.branches,
    required this.selectedId,
    required this.enabled,
    required this.onChanged,
  });

  final String name;
  final IconData icon;
  final List<DiningBranch> branches;
  final String? selectedId;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chip = Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminControlBorderColor(theme)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminBodyColor(theme),
                fontSize: AppFontSizes.size10_5,
                fontWeight: AppFontWeights.semiBold,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.px6),
          AppIcon(icon, size: 15, color: adminMutedColor(theme)),
        ],
      ),
    );

    if (!enabled) {
      return Tooltip(message: name, child: chip);
    }

    return PopupMenuButton<String>(
      tooltip: S.tablesFilterBranch,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final branch in branches)
          PopupMenuItem<String>(
            value: branch.id,
            child: Row(
              children: [
                SizedBox(
                  width: AppSizes.px18,
                  child: branch.id == selectedId
                      ? const AppIcon(
                          AppIcons.tick01,
                          size: 15,
                          color: AppColor.adminAccent,
                        )
                      : null,
                ),
                const SizedBox(width: AppSizes.px6),
                Flexible(
                  child: Text(
                    branch.nameFor(AppLocale.instance.language),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: AppFontSizes.size11,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: chip,
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: S.refresh,
      child: Material(
        color: AppColor.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: busy ? null : onPressed,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: 37,
            height: 37,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: adminControlBorderColor(theme)),
            ),
            child: busy
                ? SizedBox(
                    width: AppSizes.px14,
                    height: AppSizes.px14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: adminMutedColor(theme),
                    ),
                  )
                : AppIcon(
                    AppIcons.refresh,
                    size: 16,
                    color: adminMutedColor(theme),
                  ),
          ),
        ),
      ),
    );
  }
}
