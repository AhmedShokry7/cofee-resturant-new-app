import 'package:flutter/material.dart';

import 'package:admin_app/core/catalog/admin_product_exception.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/domain/entities/staff_edit_outcome.dart';
import 'package:admin_app/features/staff/presentation/manager/admin_staff_cubit.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_format.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_messages.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_segmented_control.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/shared/widgets/category_image_dialog.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

/// Opens the profile editor of one staff account.
///
/// It answers true when the account changed, so the page says so in its own
/// words and stays silent when the admin closed the dialog without touching
/// anything.
Future<bool?> showStaffEditDialog({
  required BuildContext context,
  required AdminStaffCubit cubit,
  required AdminStaffMember member,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => StaffEditDialog(cubit: cubit, member: member),
  );
}

/// The name, the email, the status and the picture of a staff account.
///
/// The three written fields go to `public.admin_update_staff` and the picture
/// to `public.admin_set_staff_image`: the database owns the rules — whose
/// account may be edited, whether a status is the caller's own, which folder a
/// picture may live in — so the dialog only reports what it refused.
class StaffEditDialog extends StatefulWidget {
  const StaffEditDialog({super.key, required this.cubit, required this.member});

  final AdminStaffCubit cubit;
  final AdminStaffMember member;

  @override
  State<StaffEditDialog> createState() => _StaffEditDialogState();
}

class _StaffEditDialogState extends State<StaffEditDialog> {
  static const _statuses = <String>['active', 'invited', 'suspended'];

  /// The code of each status in the words the directory already uses for it,
  /// so the picker and the badge of the row never say two different things.
  late final Map<String, String> _statusLabels = {
    for (final code in _statuses) code: StaffStatusView.of(code).label,
  };

  late final TextEditingController _name;
  late final TextEditingController _email;
  late String _status;

  /// What the directory holds for this account: a signed link while the object
  /// is in the bucket, and the file behind it is deleted through the same
  /// value, never through a path the screen invented.
  String? _picture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.member.fullName?.trim() ?? '');
    _email = TextEditingController(text: widget.member.email?.trim() ?? '');
    _status = _statuses.contains(widget.member.status)
        ? widget.member.status
        : 'active';
    _picture = widget.member.avatarUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  /// The picture the reloaded directory now carries for this account, which is
  /// a freshly signed link rather than the path that was just written.
  String? get _latestPicture {
    for (final row in widget.cubit.state.staff) {
      if (row.id == widget.member.id) return row.avatarUrl;
    }
    return _picture;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(S.editStaffTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PictureRow(
              member: widget.member,
              picture: _picture,
              onChange: _changePicture,
            ),
            const SizedBox(height: AppSpacing.md),
            CustomTextFormField(
              label: S.staffName,
              hint: S.staffName,
              controller: _name,
              bottomPadding: AppSizes.px8,
            ),
            CustomTextFormField(
              label: S.email,
              hint: S.email,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              bottomPadding: AppSizes.px8,
            ),
            Text(
              S.status,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: AppFontWeights.medium,
              ),
            ),
            const SizedBox(height: AppSizes.px6),
            AdminSegmentedControl(
              options: [for (final code in _statuses) _statusLabels[code]!],
              selected: _statusLabels[_status]!,
              onChanged: (label) => setState(
                () => _status = _statuses.firstWhere(
                  (code) => _statusLabels[code] == label,
                ),
              ),
            ),
            if (_error != null) AdminInlineError(message: _error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(S.save)),
      ],
    );
  }

  Future<void> _changePicture() async {
    await showDialog<bool>(
      context: context,
      builder: (context) => CategoryImageDialog(
        currentImageUrl: _picture,
        // The row stores a path inside `staff/<id>/`, so a hosted link is not
        // an answer here and is not offered as one.
        allowLink: false,
        onApply: (source) async {
          final bytes = source.bytes;
          final fileName = source.fileName;
          final contentType = source.contentType;
          if (bytes == null || fileName == null || contentType == null) {
            throw AdminProductException(S.staffPictureLoadFailed);
          }
          final outcome = await widget.cubit.uploadStaffImage(
            staffId: widget.member.id,
            bytes: bytes,
            fileName: fileName,
            contentType: contentType,
            replaces: _picture,
          );
          if (outcome != StaffEditOutcome.success) {
            throw AdminProductException(staffEditErrorMessage(outcome));
          }
          if (!mounted) return;
          setState(() => _picture = _latestPicture);
        },
        onRemove: () async {
          final outcome = await widget.cubit.setStaffImage(
            widget.member.id,
            null,
          );
          if (outcome != StaffEditOutcome.success) {
            throw AdminProductException(staffEditErrorMessage(outcome));
          }
          // The row goes first, then the bytes: see CategoryImageDialog.
          await widget.cubit.deleteStaffImageFile(_picture);
          if (mounted) setState(() => _picture = null);
        },
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    // An unchanged or blank field is not sent: null tells the RPC to leave the
    // column alone, so a dialog that only moved the picture cannot rewrite the
    // name from a value it read before the directory refreshed.
    final fullName = name.isEmpty || name == widget.member.fullName?.trim()
        ? null
        : name;
    final address = email.isEmpty || email == widget.member.email?.trim()
        ? null
        : email;
    final status = _status == widget.member.status ? null : _status;
    if (fullName == null && address == null && status == null) {
      // Nothing was written, so nothing is claimed to be saved: the picture is
      // stored the moment it is chosen and needs no second write.
      Navigator.of(context).pop();
      return;
    }
    final outcome = await widget.cubit.updateStaff(
      staffId: widget.member.id,
      fullName: fullName,
      email: address,
      status: status,
    );
    if (!mounted) return;
    if (outcome == StaffEditOutcome.success) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _error = staffEditErrorMessage(outcome));
  }
}

class _PictureRow extends StatelessWidget {
  const _PictureRow({
    required this.member,
    required this.picture,
    required this.onChange,
  });

  final AdminStaffMember member;
  final String? picture;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final colors = adminInitialTint(member.id);
    return Row(
      children: [
        AdminAvatarImage(
          url: picture,
          size: 56,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          fallbackText: staffInitials(member),
          placeholderColor: colors.$1,
          fallbackColor: colors.$2,
        ),
        const SizedBox(width: AppSizes.px12),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onChange,
              icon: const AppIcon(AppIcons.imageAdd01, size: 18),
              label: Text(S.staffChangePicture),
            ),
          ),
        ),
      ],
    );
  }
}
