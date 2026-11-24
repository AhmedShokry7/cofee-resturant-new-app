import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/hr/leave/domain/models/hr_leave_models.dart';
import 'package:admin_app/features/hr/leave/presentation/hr_leave_strings.dart';
import 'package:admin_app/features/hr/leave/presentation/manager/hr_leave_cubit.dart';
import 'package:admin_app/features/hr/leave/presentation/manager/hr_leave_state.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/shared/widgets/admin_create_button.dart';

class HrLeavePage extends StatefulWidget {
  const HrLeavePage({
    super.key,
    required this.canReview,
    required this.canManageTypes,
    this.cubit,
  });

  final bool canReview;
  final bool canManageTypes;
  final HrLeaveCubit? cubit;

  @override
  State<HrLeavePage> createState() => _HrLeavePageState();
}

class _HrLeavePageState extends State<HrLeavePage> {
  late final HrLeaveCubit _cubit;
  late final bool _ownsCubit;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrLeaveCubit();
    if (_ownsCubit) _cubit.load();
  }

  @override
  void dispose() {
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: BlocBuilder<HrLeaveCubit, HrLeaveState>(
      builder: (context, state) {
        if (state.status == HrLeaveStatus.loading && state.requests.isEmpty) {
          return const AdminLoadingView();
        }
        if (state.status == HrLeaveStatus.failure && state.requests.isEmpty) {
          return AdminFailureView(
            message: state.errorMessage,
            onRetry: () => _cubit.load(status: state.filterStatus),
          );
        }
        return AdminPageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageHeader(
                title: HrLeaveStrings.title,
                subtitle: HrLeaveStrings.subtitle,
                actions: [
                  if (widget.canManageTypes)
                    OutlinedButton.icon(
                      onPressed: () => _showTypes(context, state.types),
                      icon: const AppIcon(AppIcons.settings01, size: 18),
                      label: Text(HrLeaveStrings.leaveTypes),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AdminDirectoryPanel(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: state.filterStatus,
                        decoration: InputDecoration(
                          labelText: HrLeaveStrings.filter,
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(HrLeaveStrings.all),
                          ),
                          for (final status in const [
                            'pending',
                            'approved',
                            'rejected',
                            'cancelled',
                          ])
                            DropdownMenuItem<String?>(
                              value: status,
                              child: Text(_statusLabel(status)),
                            ),
                        ],
                        onChanged: (value) => _cubit.filter(value),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      tooltip: S.refresh,
                      onPressed: () => _cubit.load(status: state.filterStatus),
                      icon: const AppIcon(AppIcons.refresh),
                    ),
                  ],
                ),
              ),
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    state.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: state.requests.isEmpty
                    ? AdminEmptyState(
                        icon: AppIcons.calendar01,
                        message: HrLeaveStrings.noRequests,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) => ListView.separated(
                          itemCount: state.requests.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) => _LeaveRequestCard(
                            request: state.requests[index],
                            canReview: widget.canReview,
                            canManageBalance: widget.canReview,
                            busy:
                                state.busyRequestId == state.requests[index].id,
                            onReview: (approved) => _review(
                              context,
                              state.requests[index],
                              approved,
                            ),
                            onSetBalance: () =>
                                _setBalance(context, state.requests[index]),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _review(
    BuildContext context,
    HrLeaveRequest request,
    bool approve,
  ) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ReviewDialog(approve: approve),
    );
    if (note == null || !context.mounted) return;
    final ok = await _cubit.review(request, approve: approve, note: note);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? HrLeaveStrings.approved : HrLeaveStrings.rejected,
          ),
        ),
      );
    }
  }

  Future<void> _setBalance(BuildContext context, HrLeaveRequest request) async {
    final value = await showDialog<(int, double)>(
      context: context,
      builder: (_) => _BalanceDialog(request: request),
    );
    if (value == null || !context.mounted) return;
    final ok = await _cubit.setBalance(
      request: request,
      year: value.$1,
      entitledDays: value.$2,
    );
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(HrLeaveStrings.saveBalance)));
    }
  }

  Future<void> _showTypes(BuildContext context, List<HrLeaveType> types) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _LeaveTypesDialog(
        types: types,
        onAdd: (type) => _cubit.saveType(type, create: true),
      ),
    );
  }
}

class _LeaveRequestCard extends StatelessWidget {
  const _LeaveRequestCard({
    required this.request,
    required this.canReview,
    required this.canManageBalance,
    required this.busy,
    required this.onReview,
    required this.onSetBalance,
  });

  final HrLeaveRequest request;
  final bool canReview;
  final bool canManageBalance;
  final bool busy;
  final ValueChanged<bool> onReview;
  final VoidCallback onSetBalance;

  @override
  Widget build(BuildContext context) {
    final arabic = AppLocale.instance.isArabic;
    final pending = request.status == 'pending';
    final balance = request.balance;
    return AdminDirectoryPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                request.staffName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              _StatusChip(status: request.status),
              if (!request.isPaid)
                Chip(
                  label: Text(HrLeaveStrings.unpaid),
                  visualDensity: VisualDensity.compact,
                ),
              if (request.supportingDocument != null)
                Chip(
                  label: Text(HrLeaveStrings.supportingDocument),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            request.typeName(arabic),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              _LabeledValue(
                HrLeaveStrings.period,
                '${_date(request.startsOn)} – ${_date(request.endsOn)}',
              ),
              _LabeledValue(HrLeaveStrings.days, '${request.days}'),
              if (request.createdAtLocal != null)
                _LabeledValue(S.createdAt, request.createdAtLocal!),
            ],
          ),
          if (request.reason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _LabeledValue(HrLeaveStrings.reason, request.reason),
          ],
          if (request.reviewNote != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _LabeledValue(HrLeaveStrings.reviewNote, request.reviewNote!),
          ],
          if (balance != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.lg,
              children: [
                _LabeledValue(
                  HrLeaveStrings.entitled,
                  '${balance['entitled_days'] ?? 0}',
                ),
                _LabeledValue(
                  HrLeaveStrings.used,
                  '${balance['used_days'] ?? 0}',
                ),
                _LabeledValue(
                  HrLeaveStrings.remaining,
                  '${balance['remaining_days'] ?? 0}',
                ),
              ],
            ),
          ],
          if (canReview &&
              ((pending) || (canManageBalance && request.tracksBalance))) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (pending) ...[
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => onReview(false),
                    icon: const AppIcon(AppIcons.cancel01, size: 18),
                    label: Text(HrLeaveStrings.reject),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : () => onReview(true),
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const AppIcon(AppIcons.checkmarkCircle01, size: 18),
                    label: Text(HrLeaveStrings.approve),
                  ),
                ],
                if (request.tracksBalance)
                  TextButton.icon(
                    onPressed: busy ? null : onSetBalance,
                    icon: const AppIcon(AppIcons.edit01, size: 18),
                    label: Text(HrLeaveStrings.balance),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      Text(value),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => AppColor.adminAccent,
      'rejected' => Theme.of(context).colorScheme.error,
      'cancelled' => Theme.of(context).disabledColor,
      _ => Theme.of(context).colorScheme.tertiary,
    };
    return Chip(
      label: Text(_statusLabel(status)),
      side: BorderSide(color: color.withValues(alpha: .3)),
      backgroundColor: color.withValues(alpha: .08),
      visualDensity: VisualDensity.compact,
    );
  }
}

String _statusLabel(String status) => switch (status) {
  'approved' => HrLeaveStrings.approved,
  'rejected' => HrLeaveStrings.rejected,
  'cancelled' => HrLeaveStrings.cancelled,
  _ => HrLeaveStrings.pending,
};

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.approve});
  final bool approve;
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _controller = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.approve ? HrLeaveStrings.approve : HrLeaveStrings.reject,
    ),
    content: TextField(
      controller: _controller,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: HrLeaveStrings.reviewNote,
        errorText: _error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(HrLeaveStrings.cancel),
      ),
      FilledButton(
        onPressed: () {
          final note = _controller.text.trim();
          if (!widget.approve && note.isEmpty) {
            setState(() => _error = HrLeaveStrings.rejectionReason);
            return;
          }
          Navigator.pop(context, note);
        },
        child: Text(HrLeaveStrings.save),
      ),
    ],
  );
}

class _BalanceDialog extends StatefulWidget {
  const _BalanceDialog({required this.request});
  final HrLeaveRequest request;
  @override
  State<_BalanceDialog> createState() => _BalanceDialogState();
}

class _BalanceDialogState extends State<_BalanceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _year;
  late final TextEditingController _days;
  @override
  void initState() {
    super.initState();
    _year = TextEditingController(text: '${widget.request.startsOn.year}');
    _days = TextEditingController(
      text: '${widget.request.balance?['entitled_days'] ?? 0}',
    );
  }

  @override
  void dispose() {
    _year.dispose();
    _days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(HrLeaveStrings.balance),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _year,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: HrLeaveStrings.balanceYear),
            validator: (value) => int.tryParse(value ?? '') == null
                ? HrLeaveStrings.required
                : null,
          ),
          TextFormField(
            controller: _days,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: HrLeaveStrings.entitlementDays,
            ),
            validator: (value) {
              final parsed = double.tryParse(value ?? '');
              return parsed == null || parsed < 0
                  ? HrLeaveStrings.required
                  : null;
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(HrLeaveStrings.cancel),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, (
            int.parse(_year.text),
            double.parse(_days.text),
          ));
        },
        child: Text(HrLeaveStrings.save),
      ),
    ],
  );
}

class _LeaveTypesDialog extends StatelessWidget {
  const _LeaveTypesDialog({required this.types, required this.onAdd});
  final List<HrLeaveType> types;
  final Future<bool> Function(HrLeaveType) onAdd;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(HrLeaveStrings.leaveTypes),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: types.isEmpty
                ? Text(HrLeaveStrings.noRequests)
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: types.length,
                    itemBuilder: (_, index) {
                      final type = types[index];
                      return ListTile(
                        title: Text(type.label(AppLocale.instance.isArabic)),
                        subtitle: Text(
                          [
                            if (type.isPaid)
                              HrLeaveStrings.paid
                            else
                              HrLeaveStrings.unpaid,
                            if (type.requiresDocument)
                              HrLeaveStrings.supportingDocument,
                            if (type.tracksBalance) HrLeaveStrings.balance,
                          ].join(' · '),
                        ),
                      );
                    },
                  ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AdminCreateButton(
              label: HrLeaveStrings.addType,
              onPressed: () async {
                final type = await showDialog<HrLeaveType>(
                  context: context,
                  builder: (_) => const _LeaveTypeForm(),
                );
                if (type != null) await onAdd(type);
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(HrLeaveStrings.close),
      ),
    ],
  );
}

class _LeaveTypeForm extends StatefulWidget {
  const _LeaveTypeForm();
  @override
  State<_LeaveTypeForm> createState() => _LeaveTypeFormState();
}

class _LeaveTypeFormState extends State<_LeaveTypeForm> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _ar = TextEditingController();
  final _en = TextEditingController();
  final _days = TextEditingController();
  bool _document = false, _paid = true, _balance = false;
  @override
  void dispose() {
    _code.dispose();
    _ar.dispose();
    _en.dispose();
    _days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(HrLeaveStrings.addType),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _textField(
                _code,
                HrLeaveStrings.code,
                pattern: RegExp(r'^[a-z_]+$'),
              ),
              _textField(_ar, HrLeaveStrings.nameAr),
              _textField(_en, HrLeaveStrings.nameEn),
              TextFormField(
                controller: _days,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: HrLeaveStrings.defaultAnnualDays,
                ),
                validator: (value) {
                  if (!_balance || value == null || value.trim().isEmpty) {
                    return null;
                  }
                  final n = double.tryParse(value);
                  return n == null || n < 0 ? HrLeaveStrings.required : null;
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _document,
                title: Text(HrLeaveStrings.needsDocument),
                onChanged: (value) =>
                    setState(() => _document = value ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _paid,
                title: Text(HrLeaveStrings.paid),
                onChanged: (value) => setState(() => _paid = value ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _balance,
                title: Text(HrLeaveStrings.tracksBalance),
                onChanged: (value) => setState(() => _balance = value ?? false),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(HrLeaveStrings.cancel),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            HrLeaveType(
              id: '',
              code: _code.text.trim(),
              nameAr: _ar.text.trim(),
              nameEn: _en.text.trim(),
              requiresDocument: _document,
              isPaid: _paid,
              tracksBalance: _balance,
              defaultAnnualDays: _balance && _days.text.trim().isNotEmpty
                  ? double.tryParse(_days.text.trim())
                  : null,
            ),
          );
        },
        child: Text(HrLeaveStrings.save),
      ),
    ],
  );

  Widget _textField(
    TextEditingController controller,
    String label, {
    RegExp? pattern,
  }) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return HrLeaveStrings.required;
      if (pattern != null && !pattern.hasMatch(text)) {
        return HrLeaveStrings.required;
      }
      return null;
    },
  );
}
