import 'package:material_ui/material_ui.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/services/supabase_service.dart';

Future<void> showAccountDeletionRequestsDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _AccountDeletionRequestsDialog(),
);

class _AccountDeletionRequestsDialog extends StatefulWidget {
  const _AccountDeletionRequestsDialog();
  @override
  State<_AccountDeletionRequestsDialog> createState() => _AccountDeletionRequestsDialogState();
}

class _AccountDeletionRequestsDialogState extends State<_AccountDeletionRequestsDialog> {
  List<Map<String, dynamic>> requests = [];
  bool loading = true;
  String? error;

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await SupabaseService.client.rpc('admin_list_account_deletion_requests', params: {'p_limit': 100});
      requests = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) { error = S.couldNotLoadDashboard; }
    if (mounted) setState(() => loading = false);
  }

  @override
  void initState() { super.initState(); load(); }

  Future<void> process(String id) async {
    try {
      final result = await SupabaseService.client.functions.invoke('process-account-deletion', body: {'request_id': id});
      if (result.status < 200 || result.status >= 300) throw StateError('processing failed');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.deletionCompleted)));
      await load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.deletionFailed)));
      await load();
    }
  }

  Future<void> reject(String id) async {
    try {
      await SupabaseService.client.rpc('admin_reject_account_deletion', params: {'p_id': id, 'p_note': 'Reviewed by administration'});
      await load();
    } catch (_) { if (mounted) setState(() => error = S.pickupSaveFailed); }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(S.accountDeletionRequests),
    content: SizedBox(width: 620, child: loading
      ? const Center(child: CircularProgressIndicator())
      : error != null
          ? Text(error!)
          : requests.isEmpty
              ? Text(S.noAccountDeletionRequests)
              : ListView(shrinkWrap: true, children: [for (final row in requests)
                  ListTile(
                    title: Text('${row['user_id']}'),
                    subtitle: Text('${row['status']} • ${row['created_at']} • attempts ${row['attempt_count']}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(tooltip: S.rejectDeletion, onPressed: () => reject('${row['id']}'), icon: const Icon(Icons.close)),
                      IconButton(tooltip: S.processDeletion, onPressed: () => process('${row['id']}'), icon: const Icon(Icons.delete_forever_outlined)),
                    ]),
                  ),
                ]),
    ),
    actions: [TextButton(onPressed: load, child: Text(S.retry)), TextButton(onPressed: () => Navigator.pop(context), child: Text(S.close))],
  );
}
