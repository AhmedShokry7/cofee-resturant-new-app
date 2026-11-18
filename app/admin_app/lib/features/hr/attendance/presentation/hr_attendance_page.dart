import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/locale/app_locale.dart';
import '../../../../core/locale/app_strings.dart';
import '../../../../core/search/admin_search_controller.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../shared/widgets/admin_page_frame.dart';
import '../../../../shared/widgets/admin_page_header.dart';
import '../../../../shared/widgets/admin_state_view.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../manager/hr_attendance_cubit.dart';

class HrAttendancePage extends StatefulWidget {
  const HrAttendancePage({
    super.key,
    required this.searchController,
    required this.canReview,
    this.cubit,
  });

  final AdminSearchController searchController;
  final bool canReview;
  final HrAttendanceCubit? cubit;

  @override
  State<HrAttendancePage> createState() => _HrAttendancePageState();
}

class _HrAttendancePageState extends State<HrAttendancePage> {
  late final HrAttendanceCubit _cubit;
  late final bool _ownsCubit;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrAttendanceCubit(canReview: widget.canReview);
    _search = widget.searchController.query.trim().toLowerCase();
    if (_ownsCubit) _cubit.load();
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(HrAttendancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.searchController.bind(_onSearch);
  }

  void _onSearch(String value) {
    if (mounted) setState(() => _search = value.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: BlocBuilder<HrAttendanceCubit, HrAttendanceState>(
      builder: (context, state) {
        if (state.status == HrAttendanceStatus.loading &&
            state.sessions.isEmpty) {
          return const AdminLoadingView();
        }
        if (state.status == HrAttendanceStatus.failure &&
            state.sessions.isEmpty) {
          return AdminFailureView(
            message: state.error ?? '',
            onRetry: _cubit.load,
          );
        }
        return AdminPageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageHeader(
                title: S.hrAttendance,
                subtitle: S.hrAttendanceSubtitle,
              ),
              _filters(state),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    state.error == 'hr_date_range_invalid'
                        ? S.hrDateRangeInvalid
                        : state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: _AttendanceContent(
                  state: state,
                  cubit: _cubit,
                  canReview: widget.canReview,
                  search: _search,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _filters(HrAttendanceState state) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      _dateFilter(
        S.hrFromDate,
        state.from!,
        (value) => _cubit.load(from: value),
      ),
      _dateFilter(S.hrToDate, state.to!, (value) => _cubit.load(to: value)),
      SizedBox(
        width: 220,
        child: DropdownButtonFormField<String>(
          initialValue: state.branchId,
          isExpanded: true,
          decoration: InputDecoration(labelText: S.hrBranch, isDense: true),
          items: [
            DropdownMenuItem(value: null, child: Text(S.hrAllBranches)),
            for (final branch in state.branches)
              DropdownMenuItem(
                value: branch['id']?.toString(),
                child: Text(_branchName(branch)),
              ),
          ],
          onChanged: _cubit.setBranch,
        ),
      ),
    ],
  );

  Widget _dateFilter(
    String label,
    DateTime value,
    ValueChanged<DateTime> changed,
  ) => OutlinedButton.icon(
    onPressed: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked != null) changed(picked);
    },
    icon: const AppIcon(AppIcons.calendar01, size: 16),
    label: Text('$label: ${_date(value)}'),
  );

  String _branchName(Map<String, dynamic> branch) {
    final isArabic = AppLocale.instance.isArabic;
    final preferred = branch[isArabic ? 'name_ar' : 'name_en']?.toString();
    final fallback = branch[isArabic ? 'name_en' : 'name_ar']?.toString();
    return preferred?.isNotEmpty == true ? preferred! : fallback ?? '';
  }
}

class _AttendanceContent extends StatelessWidget {
  const _AttendanceContent({
    required this.state,
    required this.cubit,
    required this.canReview,
    required this.search,
  });

  final HrAttendanceState state;
  final HrAttendanceCubit cubit;
  final bool canReview;
  final String search;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      Tab(text: '${S.hrAttendanceSessions} (${state.sessions.length})'),
      if (canReview)
        Tab(text: '${S.hrAttendanceCorrections} (${state.corrections.length})'),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(isScrollable: true, tabs: tabs),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: TabBarView(
              children: [
                _SessionList(sessions: _filtered(state.sessions, search)),
                if (canReview)
                  _CorrectionList(
                    corrections: _filtered(state.corrections, search),
                    cubit: cubit,
                    reviewing: state.reviewing,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<Map<String, dynamic>> _filtered(
  List<Map<String, dynamic>> rows,
  String query,
) {
  if (query.isEmpty) return rows;
  return rows
      .where(
        (row) => row.values.any(
          (value) =>
              value != null && value.toString().toLowerCase().contains(query),
        ),
      )
      .toList(growable: false);
}

class _SessionList extends StatelessWidget {
  const _SessionList({required this.sessions});
  final List<Map<String, dynamic>> sessions;

  @override
  Widget build(BuildContext context) => sessions.isEmpty
      ? Center(child: Text(S.hrNoAttendance))
      : LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 760
              ? ListView.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) =>
                      _sessionCard(sessions[index]),
                )
              : _table(context),
        );

  Widget _sessionCard(Map<String, dynamic> row) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row['staff_name']?.toString() ?? '—',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('${_branchName(row)} · ${row['date_local'] ?? ''}'),
          const SizedBox(height: AppSpacing.xs),
          Text('${S.hrClockIn}: ${row['clock_in_local'] ?? '—'}'),
          Text('${S.hrClockOut}: ${row['clock_out_local'] ?? '—'}'),
          Text('${S.hrWorkedHours}: ${_minutes(row['worked_minutes'])}'),
          Text('${S.hrLateMinutes}: ${row['late_minutes'] ?? 0}'),
          Text('${S.hrEarlyMinutes}: ${row['early_minutes'] ?? 0}'),
        ],
      ),
    ),
  );

  Widget _table(BuildContext context) => SingleChildScrollView(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(S.hrEmployeeName)),
          DataColumn(label: Text(S.hrBranch)),
          DataColumn(label: Text(S.hrFromDate)),
          DataColumn(label: Text(S.hrClockIn)),
          DataColumn(label: Text(S.hrClockOut)),
          DataColumn(label: Text(S.hrWorkedHours)),
          DataColumn(label: Text(S.hrLateMinutes)),
          DataColumn(label: Text(S.hrEarlyMinutes)),
        ],
        rows: sessions
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(row['staff_name']?.toString() ?? '—')),
                  DataCell(Text(_branchName(row))),
                  DataCell(Text(row['date_local']?.toString() ?? '—')),
                  DataCell(Text(row['clock_in_local']?.toString() ?? '—')),
                  DataCell(Text(row['clock_out_local']?.toString() ?? '—')),
                  DataCell(Text(_minutes(row['worked_minutes']))),
                  DataCell(Text(row['late_minutes']?.toString() ?? '0')),
                  DataCell(Text(row['early_minutes']?.toString() ?? '0')),
                ],
              ),
            )
            .toList(),
      ),
    ),
  );
}

class _CorrectionList extends StatelessWidget {
  const _CorrectionList({
    required this.corrections,
    required this.cubit,
    required this.reviewing,
  });
  final List<Map<String, dynamic>> corrections;
  final HrAttendanceCubit cubit;
  final bool reviewing;

  @override
  Widget build(BuildContext context) => corrections.isEmpty
      ? Center(child: Text(S.hrNoCorrections))
      : ListView.separated(
          itemCount: corrections.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => _CorrectionCard(
            row: corrections[index],
            cubit: cubit,
            reviewing: reviewing,
          ),
        );
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({
    required this.row,
    required this.cubit,
    required this.reviewing,
  });
  final Map<String, dynamic> row;
  final HrAttendanceCubit cubit;
  final bool reviewing;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row['staff_name']?.toString() ?? '—',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('${_branchName(row)} · ${row['created_at_local'] ?? ''}'),
          Text('${S.hrCorrectionReason}: ${row['reason'] ?? '—'}'),
          Text(
            '${S.hrClockIn}: ${row['proposed_clock_in_local'] ?? row['current_clock_in_local'] ?? '—'}',
          ),
          Text(
            '${S.hrClockOut}: ${row['proposed_clock_out_local'] ?? row['current_clock_out_local'] ?? '—'}',
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: AppSpacing.xs,
              children: [
                TextButton.icon(
                  onPressed: reviewing ? null : () => _review(context, false),
                  icon: const AppIcon(AppIcons.cancel01, size: 16),
                  label: Text(S.hrReject),
                ),
                FilledButton.icon(
                  onPressed: reviewing ? null : () => _review(context, true),
                  icon: const AppIcon(AppIcons.checkmarkCircle01, size: 16),
                  label: Text(S.hrApprove),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _review(BuildContext context, bool approve) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? S.hrApprove : S.hrReject),
        content: TextField(
          controller: note,
          maxLength: 500,
          maxLines: 3,
          decoration: InputDecoration(labelText: S.hrReviewNote),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(approve ? S.hrApprove : S.hrReject),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await cubit.review(
        correctionId: row['id'].toString(),
        approve: approve,
        note: note.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.hrCorrectionReviewed)));
      }
    }
    note.dispose();
  }
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _minutes(Object? raw) {
  final minutes = int.tryParse(raw?.toString() ?? '') ?? 0;
  return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';
}

String _branchName(Map<String, dynamic> row) {
  final arabic = AppLocale.instance.isArabic;
  final name = row[arabic ? 'branch_name_ar' : 'branch_name_en']?.toString();
  final fallback = row[arabic ? 'branch_name_en' : 'branch_name_ar']
      ?.toString();
  return name?.isNotEmpty == true ? name! : fallback ?? '—';
}
