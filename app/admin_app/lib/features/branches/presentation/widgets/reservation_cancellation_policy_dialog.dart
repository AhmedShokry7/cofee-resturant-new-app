import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/core/services/supabase_service.dart';

Future<void> showReservationCancellationPolicyDialog({
  required BuildContext context,
  required AdminBranch branch,
}) => showDialog<void>(
  context: context,
  builder: (_) => ReservationCancellationPolicyDialog(branch: branch),
);

/// Branch-specific customer cancellation cutoffs. Values are entered in hours
/// and stored by the backend as minutes.
class ReservationCancellationPolicyDialog extends StatefulWidget {
  const ReservationCancellationPolicyDialog({super.key, required this.branch});
  final AdminBranch branch;

  @override
  State<ReservationCancellationPolicyDialog> createState() =>
      _ReservationCancellationPolicyDialogState();
}

class _ReservationCancellationPolicyDialogState
    extends State<ReservationCancellationPolicyDialog> {
  final _tableHours = TextEditingController();
  final _eventHours = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void dispose() {
    _tableHours.dispose();
    _eventHours.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    try {
      final result = await SupabaseService.client.rpc(
        'admin_get_reservation_cancellation_policy',
        params: {'p_branch_id': widget.branch.id},
      );
      if (result is! Map) throw StateError(S.reservationPolicyLoadFailed);
      final row = Map<String, dynamic>.from(result);
      _tableHours.text = (((row['table_cutoff_minutes'] as num?)?.toDouble() ?? 0) / 60).toString();
      _eventHours.text = (((row['event_cutoff_minutes'] as num?)?.toDouble() ?? 0) / 60).toString();
    } catch (_) {
      _error = S.reservationPolicyLoadFailed;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _minutes(String value) {
    final hours = double.tryParse(value.trim());
    if (hours == null || hours < 0 || hours > 168) return null;
    return (hours * 60).round();
  }

  Future<void> _save() async {
    final table = _minutes(_tableHours.text);
    final event = _minutes(_eventHours.text);
    if (table == null || event == null) {
      setState(() => _error = S.reservationPolicyInvalid);
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final result = await SupabaseService.client.rpc(
        'admin_set_reservation_cancellation_policy',
        params: {
          'p_branch_id': widget.branch.id,
          'p_table_cutoff_minutes': table,
          'p_event_cutoff_minutes': event,
        },
      );
      if (result is! Map || result['ok'] != true) {
        throw StateError(S.reservationPolicySaveFailed);
      }
      if (mounted) Navigator.of(context).pop();
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.code == '42501'
          ? S.reservationPolicyPermissionDenied
          : S.reservationPolicySaveFailed);
    } catch (_) {
      if (mounted) setState(() => _error = S.reservationPolicySaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(S.reservationCancellationPolicy),
    content: _loading
        ? const SizedBox(height: 72, child: Center(child: CircularProgressIndicator()))
        : SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(widget.branch.nameFor(AppLocale.instance.language)),
              const SizedBox(height: 12),
              TextField(controller: _tableHours, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: S.tableCancellationCutoffHours, helperText: S.reservationPolicyHoursHint)),
              const SizedBox(height: 12),
              TextField(controller: _eventHours, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: S.eventCancellationCutoffHours, helperText: S.reservationPolicyHoursHint)),
              if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
            ]),
          ),
    actions: [
      TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: Text(S.cancel)),
      FilledButton(onPressed: _loading || _saving ? null : _save, child: Text(_saving ? S.saving : S.save)),
    ],
  );
}
