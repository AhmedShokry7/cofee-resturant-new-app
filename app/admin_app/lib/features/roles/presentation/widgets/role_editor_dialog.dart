import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/roles/data/models/admin_role.dart';
import 'package:admin_app/features/roles/presentation/manager/admin_role_cubit.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_permission_selector.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// Loads the catalogue, then opens the create/edit role dialog.
Future<void> showRoleEditorDialog({
  required BuildContext context,
  required AdminRoleCubit cubit,
  AdminRole? role,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  List<Map<String, dynamic>> catalog;
  try {
    catalog = await cubit.loadPermissions();
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(S.permissionsLoadFailed)));
    return;
  }
  if (!context.mounted) return;

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) =>
        AdminRoleEditorDialog(cubit: cubit, catalog: catalog, role: role),
  );
  if (saved != true) return;

  messenger.showSnackBar(
    SnackBar(content: Text(role == null ? S.roleCreated : S.roleUpdated)),
  );
  await cubit.load();
}

/// Creates a role or edits one, submitting the complete permission set in a
/// single atomic RPC.
class AdminRoleEditorDialog extends StatefulWidget {
  const AdminRoleEditorDialog({
    super.key,
    required this.cubit,
    required this.catalog,
    this.role,
  });

  final AdminRoleCubit cubit;
  final List<Map<String, dynamic>> catalog;
  final AdminRole? role;

  @override
  State<AdminRoleEditorDialog> createState() => _AdminRoleEditorDialogState();
}

class _AdminRoleEditorDialogState extends State<AdminRoleEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameAr;
  late final TextEditingController _nameEn;
  late final TextEditingController _description;
  late Set<String> _selected;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.role != null;
  bool get _identityLocked => widget.role?.isSystem == true;

  @override
  void initState() {
    super.initState();
    final role = widget.role;
    _nameAr = TextEditingController(text: role?.nameAr ?? '');
    _nameEn = TextEditingController(text: role?.nameEn ?? '');
    _description = TextEditingController(text: role?.description ?? '');
    _selected = <String>{...?role?.permissions};
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final nameAr = _nameAr.text.trim();
      final nameEn = _nameEn.text.trim();
      final description = _description.text.trim();
      final permissions = _selected.toList()..sort();
      final role = widget.role;
      if (role == null) {
        await widget.cubit.createRole(
          nameAr: nameAr,
          nameEn: nameEn,
          description: description,
          permissionCodes: permissions,
        );
      } else {
        await widget.cubit.updateRole(
          roleId: role.id,
          nameAr: nameAr,
          nameEn: nameEn,
          description: description,
          permissionCodes: permissions,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = adminErrorMessage(
          error,
          fallback: S.roleSaveFailed,
          reasons: {
            'role name in arabic is required': S.roleNameRequired,
            'a role with this name already exists': S.errorAlreadyExists,
            'system role identity cannot be changed':
                S.roleSystemIdentityLocked,
            'cannot modify a role you hold': S.errorNoPermission,
            'cannot grant a permission you do not hold':
                S.permissionsCannotGrant,
            'owner-only permission': S.errorNoPermission,
            'owner role is immutable': S.roleOwnerReadOnly,
          },
        );
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final height = math.min(760.0, size.height - 48);
    final title = _isEditing ? S.roleEditTitle : S.roleCreateTitle;
    final subtitle = _isEditing ? S.roleEditSubtitle : S.roleCreateSubtitle;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760, maxHeight: height),
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminDialogHeader(
                title: title,
                subtitle: subtitle,
                onClose: _saving ? null : () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.lg,
                            0,
                          ),
                          child: AdminErrorBanner(message: _error!),
                        ),
                      if (_identityLocked)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.lg,
                            0,
                          ),
                          child: Text(
                            S.roleSystemIdentityLocked,
                            style: TextStyle(
                              color: adminMutedColor(theme),
                              fontSize: AppFontSizes.size10,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          0,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 560;
                            final fields = <Widget>[
                              TextFormField(
                                controller: _nameAr,
                                enabled: !_identityLocked,
                                textInputAction: TextInputAction.next,
                                maxLength: 80,
                                decoration: adminDialogFieldDecoration(
                                  context,
                                  label: S.roleNameAr,
                                  hint: S.roleNameAr,
                                  required: true,
                                ),
                                validator: (value) =>
                                    (value ?? '').trim().isEmpty
                                    ? S.roleNameRequired
                                    : null,
                              ),
                              TextFormField(
                                controller: _nameEn,
                                enabled: !_identityLocked,
                                textInputAction: TextInputAction.next,
                                maxLength: 80,
                                decoration: adminDialogFieldDecoration(
                                  context,
                                  label: S.roleNameEn,
                                  hint: S.roleNameEnHint,
                                ),
                              ),
                            ];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (wide)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: fields[0]),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(child: fields[1]),
                                    ],
                                  )
                                else ...[
                                  fields[0],
                                  fields[1],
                                ],
                                TextFormField(
                                  controller: _description,
                                  enabled: !_identityLocked,
                                  maxLines: 2,
                                  maxLength: 500,
                                  decoration: adminDialogFieldDecoration(
                                    context,
                                    label: S.roleDescriptionLabel,
                                    hint: S.roleDescriptionHint,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Divider(height: 1, color: adminRowBorderColor(theme)),
                      Expanded(
                        child: AdminPermissionSelector(
                          catalog: widget.catalog,
                          selected: _selected,
                          onChanged: (next) {
                            setState(() => _selected = next);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AdminDialogFooter(
                saving: _saving,
                onCancel: _saving
                    ? () {}
                    : () => Navigator.of(context).pop(false),
                onSave: _save,
                saveKey: const Key('role-editor-save'),
                saveLabel: _isEditing ? S.save : S.createRole,
                savingLabel: S.saving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
