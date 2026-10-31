import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/constants/app_patterns.dart';
import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/presentation/manager/admin_staff_cubit.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_code_block.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_messages.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

/// يفتح نموذج دعوة موظف جديد.
///
/// يجيب true حين كُتبت الدعوة فعلًا، فيقول الصفحة ذلك بصوتها ولا يقول شيئًا حين
/// يغلق المدير النموذج بلا إرسال.
Future<bool?> showStaffInviteDialog({
  required BuildContext context,
  required AdminStaffCubit cubit,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => StaffInviteDialog(cubit: cubit),
  );
}

/// البريد والاسم والدور والفرع، ثم رمز القبول الذي تخرجه القاعدة مرة واحدة.
///
/// القائمة التي تملأ الاختيارين تأتي من `public.admin_staff_invite_options()`:
/// هي التي تعرف أي دور يجوز لهذا الموظف وأي فرع هو في نطاقه، فلا يعرض النموذج
/// خيارًا ترفضه خطوة الحفظ من بعده.
class StaffInviteDialog extends StatefulWidget {
  const StaffInviteDialog({super.key, required this.cubit});

  final AdminStaffCubit cubit;

  @override
  State<StaffInviteDialog> createState() => _StaffInviteDialogState();
}

class _StaffInviteDialogState extends State<StaffInviteDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();

  AdminInviteOptions? _options;
  String? _roleCode;
  String? _branchId;
  String? _error;
  bool _sending = false;

  /// ما خرج من `admin_invite_staff` عند النجاح: لا يُقرأ من جديد من قائمة
  /// الدعوات، لأن الرمز يصل مرة واحدة إلى كاتب الدعوة.
  String? _issuedCode;
  String? _issuedEmail;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await widget.cubit.loadInviteOptions();
      if (!mounted) return;
      setState(() {
        _options = options;
        _roleCode = options.roles.isEmpty ? null : options.roles.first.id;
        // دعوة بلا فرع هي منح على مستوى المنصة كله، فلا تُختار لمدير فرع.
        _branchId = options.branches.isEmpty
            ? null
            : options.canOfferAnyBranch
            ? null
            : options.branches.first.id;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = adminErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_issuedCode != null) return _buildCodeShown(theme);
    return _buildForm(theme);
  }

  Widget _buildForm(ThemeData theme) {
    final options = _options;
    return AlertDialog(
      title: Text(S.staffInviteTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              S.staffInviteDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: adminMutedColor(theme),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (options == null && _error == null)
              _LoadingRow(label: S.staffInviteLoadingOptions)
            else if (options != null &&
                options.roles.isEmpty &&
                options.branches.isEmpty)
              AdminInlineError(message: S.staffInviteNoOptions)
            else ...[
              CustomTextFormField(
                label: S.staffInviteName,
                hint: S.staffInviteName,
                controller: _name,
                bottomPadding: AppSizes.px8,
              ),
              CustomTextFormField(
                label: S.staffInviteEmail,
                hint: S.staffInviteEmail,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                bottomPadding: AppSizes.px8,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: DropdownButtonFormField<String>(
                  initialValue: _roleCode,
                  decoration: InputDecoration(labelText: S.staffInviteRole),
                  items: [
                    for (final role
                        in options?.roles ?? const <AdminInviteChoice>[])
                      DropdownMenuItem(
                        value: role.id,
                        child: Text(role.name()),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _roleCode = value);
                  },
                ),
              ),
              if (options?.canOfferAnyBranch ?? false)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _branchId,
                    decoration: InputDecoration(labelText: S.staffInviteBranch),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(S.staffInviteAllBranches),
                      ),
                      for (final branch
                          in options?.branches ?? const <AdminInviteChoice>[])
                        DropdownMenuItem(
                          value: branch.id,
                          child: Text(branch.name()),
                        ),
                    ],
                    onChanged: (value) => setState(() => _branchId = value),
                  ),
                )
              else if (options != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: DropdownButtonFormField<String>(
                    initialValue: _branchId,
                    decoration: InputDecoration(labelText: S.staffInviteBranch),
                    items: [
                      for (final branch in options.branches)
                        DropdownMenuItem(
                          value: branch.id,
                          child: Text(branch.name()),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _branchId = value);
                    },
                  ),
                ),
            ],
            if (_error != null) AdminInlineError(message: _error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
        FilledButton(
          // `_ready()` تنفي أثناء الكتابة نفسها، فلا إرسالان لبريد واحد.
          onPressed: _ready() ? _send : null,
          child: Text(S.staffInviteSend),
        ),
      ],
    );
  }

  Widget _buildCodeShown(ThemeData theme) {
    return AlertDialog(
      title: Text(S.staffInviteCodeTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _issuedEmail ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: AppFontWeights.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              S.staffInviteCodeHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: adminMutedColor(theme),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            StaffCodeBlock(code: _issuedCode!),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(S.close),
        ),
      ],
    );
  }

  bool _ready() => !_sending && _options != null && _roleCode != null;

  /// التحقق عند الضغط لا عند البناء: الحقلان لا يملكان مستمعًا يعيد البناء،
  /// فزرّ معلَّق بصيغة النص يبقى مطفأً إلى أن يمسّه سبب آخر.
  Future<void> _send() async {
    final roleCode = _roleCode;
    if (roleCode == null) return;
    final name = _name.text.trim();
    final email = _email.text.trim();
    // نفس نصّي السببين اللذين ترجعهما القاعدة، فلا معنىً واحد بصيغتين.
    if (name.length < 2) {
      setState(() => _error = S.staffEditInvalidName);
      return;
    }
    if (!AppPatterns.email.hasMatch(email)) {
      setState(() => _error = S.staffEditInvalidEmail);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await widget.cubit.inviteStaff(
      email: _email.text.trim(),
      fullName: _name.text.trim(),
      roleCode: roleCode,
      branchId: _branchId,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (result.isSuccess) {
      setState(() {
        _issuedCode = result.code;
        _issuedEmail = result.email;
      });
      return;
    }
    setState(() => _error = staffInviteErrorMessage(result.outcome));
  }
}

/// سطر انتظار قصير داخل النموذج، بلا شاشة تحميل تغطي الحوار كله.
class _LoadingRow extends StatelessWidget {
  const _LoadingRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSizes.px8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: adminMutedColor(theme),
          ),
        ),
      ],
    );
  }
}
