import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';

/// معرض القوالب: قائمة القوالب المحفوظة (RPC 228) بتطبيق وحذف، وحفظ
/// المسودة الحالية كقالب جديد.
///
/// التطبيق يمس المسودة فقط — القالب يُنسخ إلى المحرّر بنفس تدقيق النشر،
/// ولا يلمس ما يراه الزبون أبدًا.
class TemplatesDialog extends StatefulWidget {
  const TemplatesDialog({super.key});

  @override
  State<TemplatesDialog> createState() => _TemplatesDialogState();
}

class _TemplatesDialogState extends State<TemplatesDialog> {
  List<DesignTemplateInfo>? _templates;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final templates =
          await context.read<VisualEditorCubit>().loadTemplates();
      if (!mounted) return;
      setState(() => _templates = templates);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    return AlertDialog(
      title: Text(S.visualEditorTemplatesTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // حفظ الحالي كقالب: اسم + زر، في أعلى المعرض.
            _SaveTemplateRow(
              saving: _saving,
              muted: muted,
              dark: dark,
              onSave: _saveAsTemplate,
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: _buildList(dark, muted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.close),
        ),
      ],
    );
  }

  Widget _buildList(bool dark, Color muted) {
    final templates = _templates;
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColor.trendNegative,
            fontSize: AppFontSizes.size12,
          ),
        ),
      );
    }
    if (templates == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (templates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          S.visualEditorNoTemplates,
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: AppFontSizes.size13),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return ListTile(
          dense: true,
          leading: Icon(
            AppIcons.folder01,
            size: AppDimensions.iconSizeSm,
            color: muted,
          ),
          title: Text(
            template.name,
            style: TextStyle(
              fontSize: AppFontSizes.size13,
              color: dark ? AppColor.darkText : AppColor.adminBody,
            ),
          ),
          subtitle: template.updatedAt == null
              ? null
              : Text(
                  '${template.updatedAt!.year}-'
                  '${template.updatedAt!.month.toString().padLeft(2, '0')}-'
                  '${template.updatedAt!.day.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: AppFontSizes.size11),
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => _apply(template),
                child: Text(S.visualEditorApplyTemplate),
              ),
              IconButton(
                tooltip: S.visualEditorDeleteTemplate,
                icon: Icon(
                  AppIcons.delete02,
                  size: AppDimensions.iconSizeSm,
                  color: AppColor.trendNegative,
                ),
                onPressed: () => _delete(template),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _apply(DesignTemplateInfo template) async {
    final ok = await context.read<VisualEditorCubit>().applyTemplate(
          template.id,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.visualEditorTemplateApplied)),
      );
    }
  }

  Future<void> _delete(DesignTemplateInfo template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.visualEditorDeleteTemplate),
        content: Text(S.visualEditorDeleteTemplateConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(S.visualEditorDeleteTemplate),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok =
        await context.read<VisualEditorCubit>().deleteTemplate(template.id);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.visualEditorTemplateDeleted)),
      );
      _load();
    }
  }

  Future<void> _saveAsTemplate(String name) async {
    setState(() => _saving = true);
    final template = await context
        .read<VisualEditorCubit>()
        .saveCurrentAsTemplate(name);
    if (!mounted) return;
    setState(() => _saving = false);
    if (template != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.visualEditorTemplateSaved)),
      );
      _load();
    }
  }
}

class _SaveTemplateRow extends StatefulWidget {
  const _SaveTemplateRow({
    required this.saving,
    required this.muted,
    required this.dark,
    required this.onSave,
  });

  final bool saving;
  final Color muted;
  final bool dark;
  final void Function(String) onSave;

  @override
  State<_SaveTemplateRow> createState() => _SaveTemplateRowState();
}

class _SaveTemplateRowState extends State<_SaveTemplateRow> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            maxLength: 60,
            decoration: InputDecoration(
              labelText: S.visualEditorTemplateNameLabel,
              hintText: S.visualEditorTemplateNameHint,
              counterText: '',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            style: TextStyle(
              fontSize: AppFontSizes.size13,
              color: dark ? AppColor.darkText : AppColor.adminBody,
            ),
            onSubmitted: _submit,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton.tonal(
          onPressed: widget.saving ? null : () => _submit(_controller.text),
          child: Text(S.visualEditorSaveTemplate),
        ),
      ],
    );
  }

  void _submit(String value) {
    if (value.trim().isEmpty) return;
    widget.onSave(value);
  }
}
