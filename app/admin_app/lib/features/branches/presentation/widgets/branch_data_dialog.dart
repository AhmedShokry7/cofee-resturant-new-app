import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/branches/domain/entities/admin_branch_draft.dart';
import 'package:admin_app/features/branches/domain/entities/branch_save_outcome.dart';
import 'package:admin_app/features/branches/presentation/manager/admin_branch_cubit.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_location_picker.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_messages.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';

/// Opens the dialog that creates a branch through the cubit of the page.
Future<bool?> showBranchCreateDialog({
  required BuildContext context,
  required AdminBranchCubit cubit,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => BranchDataDialog(onSave: cubit.saveBranch),
  );
}

/// Opens the dialog that edits a branch through the cubit of the page.
Future<bool?> showBranchEditDialog({
  required BuildContext context,
  required AdminBranchCubit cubit,
  required AdminBranch branch,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) =>
        BranchDataDialog(initialBranch: branch, onSave: cubit.saveBranch),
  );
}

/// The dialog that creates or edits a branch: identity, location and hours.
class BranchDataDialog extends StatefulWidget {
  const BranchDataDialog({super.key, required this.onSave, this.initialBranch});

  /// Creates or updates the branch; the outcome decides whether to close.
  final Future<BranchSaveOutcome> Function(AdminBranchDraft draft) onSave;

  /// When provided the dialog edits this branch instead of creating one.
  final AdminBranch? initialBranch;

  @override
  State<BranchDataDialog> createState() => _BranchDataDialogState();
}

class _BranchDataDialogState extends State<BranchDataDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameArController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _phoneController;
  late final TextEditingController _legalNameController;
  late final TextEditingController _vatNumberController;
  late final TextEditingController _opensAtController;
  late final TextEditingController _closesAtController;
  late String _address;
  double? _pickedLatitude;
  double? _pickedLongitude;
  int _locationKey = 0;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final branch = widget.initialBranch;
    _codeController = TextEditingController(text: branch?.code ?? '');
    _nameArController = TextEditingController(text: branch?.nameAr ?? '');
    _nameEnController = TextEditingController(text: branch?.nameEn ?? '');
    _phoneController = TextEditingController(text: branch?.phone ?? '');
    _legalNameController = TextEditingController(text: branch?.legalName ?? '');
    _vatNumberController = TextEditingController(text: branch?.vatNumber ?? '');
    _address = branch?.address ?? '';
    _pickedLatitude = branch?.latitude;
    _pickedLongitude = branch?.longitude;
    _opensAtController = TextEditingController(
      text: _timeForInput(branch?.opensAt),
    );
    _closesAtController = TextEditingController(
      text: _timeForInput(branch?.closesAt),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameArController.dispose();
    _nameEnController.dispose();
    _phoneController.dispose();
    _legalNameController.dispose();
    _vatNumberController.dispose();
    _opensAtController.dispose();
    _closesAtController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;

    final code = _codeController.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9_-]{1,24}$').hasMatch(code)) {
      setState(() => _error = S.branchSaveInvalidCode);
      return;
    }
    final nameAr = _nameArController.text.trim();
    if (nameAr.isEmpty) {
      setState(() => _error = S.branchNeedsName);
      return;
    }
    final address = _address.trim();
    if (address.isEmpty) {
      setState(() => _error = S.branchNeedsAddress);
      return;
    }
    final legalName = _legalNameController.text.trim();
    if (legalName.length > 200) {
      setState(() => _error = S.branchInvalidLegalName);
      return;
    }
    final vatNumber = normalizeDigits(_vatNumberController.text.trim());
    if (vatNumber.isNotEmpty && !RegExp(r'^3\d{13}3$').hasMatch(vatNumber)) {
      setState(() => _error = S.branchInvalidVatNumber);
      return;
    }

    final (opensAt, opensValid) = _parseTime(_opensAtController.text);
    final (closesAt, closesValid) = _parseTime(_closesAtController.text);
    if (!opensValid ||
        !closesValid ||
        (opensAt == null) != (closesAt == null) ||
        (opensAt != null && opensAt.compareTo(closesAt!) >= 0)) {
      setState(() => _error = S.branchInvalidHours);
      return;
    }

    final nameEn = _nameEnController.text.trim();
    final phone = _phoneController.text.trim();
    final draft = AdminBranchDraft(
      id: widget.initialBranch?.id,
      code: code,
      nameAr: nameAr,
      nameEn: nameEn.isEmpty ? nameAr : nameEn,
      address: address,
      latitude: _pickedLatitude,
      longitude: _pickedLongitude,
      phone: phone.isEmpty ? null : phone,
      legalName: legalName.isEmpty ? null : legalName,
      vatNumber: vatNumber.isEmpty ? null : vatNumber,
      opensAt: opensAt,
      closesAt: closesAt,
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    final outcome = await widget.onSave(draft);
    if (!mounted) return;
    if (outcome == BranchSaveOutcome.saved) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = branchSaveErrorMessage(outcome);
    });
  }

  /// Accepts `HH:mm` or `HH:mm:ss`; the bool is false only for invalid text.
  (String?, bool) _parseTime(String input) {
    final value = input.trim();
    if (value.isEmpty) return (null, true);
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(value);
    if (match == null) return (null, false);
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return (null, false);
    final clock =
        '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:00';
    return (clock, true);
  }

  String _timeForInput(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '';
    final parts = text.split(':');
    if (parts.length < 2) return text;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return text;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  void _clearLocation() {
    setState(() {
      _pickedLatitude = null;
      _pickedLongitude = null;
      _locationKey++;
    });
  }

  void _close() {
    if (_saving) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final branch = widget.initialBranch;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal:
            MediaQuery.sizeOf(context).width < AppBreakpoints.dialogPadding
            ? AppSpacing.md
            : AppSpacing.xxxl,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: branch == null ? S.addBranch : S.editBranch,
              subtitle: branch == null ? S.branchesDescription : branch.code,
              onClose: _close,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      AdminErrorBanner(message: _error!),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final fields = [
                          _BranchField(
                            controller: _codeController,
                            label: '${S.branchCode} *',
                            textCapitalization: TextCapitalization.characters,
                          ),
                          _BranchField(
                            controller: _phoneController,
                            label: S.branchPhone,
                            keyboardType: TextInputType.phone,
                          ),
                        ];
                        return constraints.maxWidth < 480
                            ? Column(
                                children: [
                                  fields[0],
                                  const SizedBox(height: AppSpacing.md),
                                  fields[1],
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: fields[0]),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(child: fields[1]),
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _BranchField(
                      controller: _nameArController,
                      label: '${S.nameAr} *',
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _BranchField(
                      controller: _nameEnController,
                      label: S.nameEn,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Text(
                          S.branchLocation,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColor.greyColor,
                                fontWeight: AppFontWeights.semiBold,
                              ),
                        ),
                        const Spacer(),
                        if (_pickedLatitude != null && _pickedLongitude != null)
                          TextButton.icon(
                            onPressed: _saving ? null : _clearLocation,
                            icon: const Icon(AppIcons.cancel01, size: 15),
                            label: Text(S.branchClearLocation),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AdminLocationPicker(
                      key: ValueKey(_locationKey),
                      initialLatitude: _pickedLatitude,
                      initialLongitude: _pickedLongitude,
                      initialAddress: _address,
                      onAddressChanged: (value) => _address = value,
                      onPicked: (point, address) {
                        setState(() {
                          _pickedLatitude = point.latitude;
                          _pickedLongitude = point.longitude;
                          if (address != null && address.trim().isNotEmpty) {
                            _address = address.trim();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _BranchField(
                            controller: _opensAtController,
                            label: S.opensAt,
                            hint: S.branchHoursHint,
                            keyboardType: TextInputType.datetime,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _BranchField(
                            controller: _closesAtController,
                            label: S.closesAt,
                            hint: S.branchHoursHint,
                            keyboardType: TextInputType.datetime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      S.branchTaxInvoiceSection,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColor.greyColor,
                        fontWeight: AppFontWeights.semiBold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      S.branchTaxInvoiceHint,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColor.greyColor),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final fields = [
                          _BranchField(
                            controller: _legalNameController,
                            label: S.branchLegalName,
                          ),
                          _BranchField(
                            controller: _vatNumberController,
                            label: S.branchVatNumber,
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                          ),
                        ];
                        return constraints.maxWidth < 480
                            ? Column(
                                children: [
                                  fields[0],
                                  const SizedBox(height: AppSpacing.md),
                                  fields[1],
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(flex: 3, child: fields[0]),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(flex: 2, child: fields[1]),
                                ],
                              );
                      },
                    ),
                  ],
                ),
              ),
            ),
            AdminDialogFooter(
              saving: _saving,
              onCancel: _close,
              onSave: _submit,
              saveKey: const Key('branch-data-save'),
              saveLabel: S.save,
              savingLabel: S.saving,
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchField extends StatelessWidget {
  const _BranchField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.textDirection,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    textDirection: textDirection,
    textCapitalization: textCapitalization,
    decoration: InputDecoration(labelText: label, hintText: hint),
  );
}
