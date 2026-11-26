import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/data/repositories/order_issue_repository.dart';

class OrderIssuePanel extends StatefulWidget {
  const OrderIssuePanel({
    super.key,
    required this.order,
    required this.canManage,
  });
  final String order;
  final bool canManage;
  @override
  State<OrderIssuePanel> createState() => _OrderIssuePanelState();
}

class _OrderIssuePanelState extends State<OrderIssuePanel> {
  final repo = const OrderIssueRepository();
  late Future<List<Map<String, dynamic>>> rows;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    rows = repo.list(widget.order);
  }

  void reload() => setState(() => rows = repo.list(widget.order));
  Map<String, String> get reasons => {
    'missing': S.issueMissing,
    'incorrect': S.issueIncorrect,
    'delay': S.issueDelay,
    'other': S.issueOther,
  };
  Future<void> compose(String id) async {
    if (busy) return;
    String message = '';
    final send = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, update) => AlertDialog(
          title: Text(S.issueReply),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: S.issueReply),
                  onChanged: (v) => update(() => message = v.trim()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(S.cancel),
            ),
            TextButton(
              onPressed: message.isEmpty
                  ? null
                  : () => Navigator.pop(dialog, true),
              child: Text(S.issueSend),
            ),
          ],
        ),
      ),
    );
    if (send != true || !mounted) return;
    setState(() => busy = true);
    try {
      await repo.reply(id, message);
      if (mounted) reload();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.issueRetry)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: rows,
        builder: (context, state) {
          if (state.hasError)
            return TextButton(onPressed: reload, child: Text(S.retry));
          if (!state.hasData) return const SizedBox.shrink();
          final issues = state.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final i in issues)
                Card(
                  child: ListTile(
                    title: Text(reasons[i['reason']] ?? S.issueTitle),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i['message'] as String),
                        if (i['photo'] != null)
                          Image.memory(
                            base64Decode(i['photo'] as String),
                            height: 100,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        Text(
                          i['reply'] == null
                              ? S.issuePending
                              : '${S.issueReply}: ${i['reply']}',
                        ),
                        if (widget.canManage && i['reply'] == null)
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => compose(i['id'] as String),
                            child: Text(S.issueReply),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
}
