import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/orders/data/repositories/order_issue_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

class OrderIssuePanel extends StatefulWidget {
  const OrderIssuePanel({super.key, required this.order, required this.lines});
  final String order;
  final List<OrderItemModel> lines;
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
  Future<void> compose() async {
    if (busy) return;
    String message = '';
    String reason = 'missing';
    String? item, photo;
    final send = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, update) => AlertDialog(
          title: Text(S.issueNew),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  items: reasons.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => update(() => reason = v!),
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: '',
                  items: [
                    DropdownMenuItem(value: '', child: Text(S.issueEntire)),
                    for (final l in widget.lines)
                      DropdownMenuItem(
                        value: l.id,
                        child: Text(
                          l.product.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => item = v == '' ? null : v,
                ),
                CustomTextButton(
                  onPressed: () async {
                    try {
                      final file = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 960,
                        maxHeight: 960,
                        imageQuality: 65,
                      );
                      if (file == null || !dialog.mounted) return;
                      if (await file.length() > 300000) {
                        if (dialog.mounted)
                          ScaffoldMessenger.of(dialog).showSnackBar(
                            SnackBar(content: Text(S.issuePhotoLarge)),
                          );
                        return;
                      }
                      final encoded = base64Encode(await file.readAsBytes());
                      if (dialog.mounted) update(() => photo = encoded);
                    } catch (_) {
                      if (dialog.mounted)
                        ScaffoldMessenger.of(
                          dialog,
                        ).showSnackBar(SnackBar(content: Text(S.issueRetry)));
                    }
                  },
                  child: Text(photo == null ? S.issuePhoto : S.issuePhotoReady),
                ),
                TextField(
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: S.issueNotes),
                  onChanged: (v) => update(() => message = v.trim()),
                ),
              ],
            ),
          ),
          actions: [
            CustomTextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(S.cancel),
            ),
            CustomTextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(S.issueSend),
            ),
          ],
        ),
      ),
    );
    if (send != true || !mounted) return;
    setState(() => busy = true);
    try {
      await repo.report(widget.order, item, reason, message, photo);
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
            return CustomTextButton(onPressed: reload, child: Text(S.retry));
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
                      ],
                    ),
                  ),
                ),
              if (!issues.any((i) => i['reply'] == null))
                CustomBtn(
                  text: S.issueNew,
                  variant: BtnVariant.outlined,
                  onPressed: busy ? null : compose,
                ),
            ],
          );
        },
      );
}
