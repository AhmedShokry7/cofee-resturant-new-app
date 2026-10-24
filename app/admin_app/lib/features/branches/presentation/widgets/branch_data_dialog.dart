import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/branches/presentation/manager/admin_branch_cubit.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_location_picker.dart';

/// Opens the dialog that creates a branch through the cubit of the page.
Future<void> showBranchCreateDialog({
  required BuildContext context,
  required AdminBranchCubit cubit,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => BranchDataDialog(
      onSave:
          ({
            required String code,
            required String nameAr,
            required String nameEn,
            required String address,
            double? latitude,
            required bool clearLatitude,
            double? longitude,
            required bool clearLongitude,
            String? phone,
            required bool clearPhone,
            String? opensAt,
            required bool clearOpensAt,
            String? closesAt,
            required bool clearClosesAt,
          }) {
            return cubit.createBranch(
              code: code,
              nameAr: nameAr,
              nameEn: nameEn,
              address: address,
              latitude: latitude,
              longitude: longitude,
              phone: phone,
              opensAt: opensAt,
              closesAt: closesAt,
            );
          },
    ),
  );
}

/// Opens the dialog that edits a branch through the cubit of the page.
Future<void> showBranchEditDialog({
  required BuildContext context,
  required AdminBranchCubit cubit,
  required AdminBranch branch,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => BranchDataDialog(
      initialBranch: branch,
      onSave:
          ({
            required String code,
            required String nameAr,
            required String nameEn,
            required String address,
            double? latitude,
            required bool clearLatitude,
            double? longitude,
            required bool clearLongitude,
            String? phone,
            required bool clearPhone,
            String? opensAt,
            required bool clearOpensAt,
            String? closesAt,
            required bool clearClosesAt,
          }) {
            return cubit.updateBranch(
              branchId: branch.id,
              code: code,
              nameAr: nameAr,
              nameEn: nameEn,
              address: address,
              latitude: latitude,
              clearLatitude: clearLatitude,
              longitude: longitude,
              clearLongitude: clearLongitude,
              phone: phone,
              clearPhone: clearPhone,
              opensAt: opensAt,
              clearOpensAt: clearOpensAt,
              closesAt: closesAt,
              clearClosesAt: clearClosesAt,
            );
          },
    ),
  );
}

/// The dialog that creates or edits a branch.
class BranchDataDialog extends StatefulWidget {
  const BranchDataDialog({super.key, required this.onSave, this.initialBranch});

  /// Creates or updates the branch; returns the saved branch.
  final Future<AdminBranch> Function({
    required String code,
    required String nameAr,
    required String nameEn,
    required String address,
    double? latitude,
    required bool clearLatitude,
    double? longitude,
    required bool clearLongitude,
    String? phone,
    required bool clearPhone,
    String? opensAt,
    required bool clearOpensAt,
    String? closesAt,
    required bool clearClosesAt,
  })
  onSave;

  /// When provided the dialog edits this branch instead of creating one.
  final AdminBranch? initialBranch;

  @override
  State<BranchDataDialog> createState() => _BranchDataDialogState();
}

class _BranchDataDialogState extends State<BranchDataDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameArController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  double? _pickedLatitude;
  double? _pickedLongitude;
  late final TextEditingController _opensAtController;
  late final TextEditingController _closesAtController;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final branch = widget.initialBranch;
    _codeController = TextEditingController(text: branch?.code ?? '');
    _nameArController = TextEditingController(text: branch?.nameAr ?? '');
    _nameEnController = TextEditingController(text: branch?.nameEn ?? '');
    _addressController = TextEditingController(text: branch?.address ?? '');
    _phoneController = TextEditingController(text: branch?.phone ?? '');
    _latitudeController = TextEditingController(
      text: branch?.latitude?.toString() ?? '',
    );
    _longitudeController = TextEditingController(
      text: branch?.longitude?.toString() ?? '',
    );
    _pickedLatitude = branch?.latitude;
    _pickedLongitude = branch?.longitude;
    _opensAtController = TextEditingController(text: branch?.opensAt ?? '');
    _closesAtController = TextEditingController(text: branch?.closesAt ?? '');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameArController.dispose();
    _nameEnController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _opensAtController.dispose();
    _closesAtController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_saving) return;

    final code = _codeController.text.trim().toUpperCase();
    final nameAr = _nameArController.text.trim();
    final nameEn = _nameEnController.text.trim();

    if (code.isEmpty) {
      setState(() => _error = S.branchNeedsCode);
      return;
    }
    if (nameAr.isEmpty) {
      setState(() => _error = S.branchNeedsName);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final branch = widget.initialBranch;
    try {
      await widget.onSave(
        code: code,
        nameAr: nameAr,
        nameEn: nameEn.isEmpty ? nameAr : nameEn,
        address: _addressController.text.trim(),
        latitude: _pickedLatitude,
        clearLatitude:
            branch != null &&
            _pickedLatitude == null &&
            _addressController.text.trim().isEmpty,
        longitude: _pickedLongitude,
        clearLongitude:
            branch != null &&
            _pickedLongitude == null &&
            _addressController.text.trim().isEmpty,
        phone: _phoneController.text.trim(),
        clearPhone: branch != null && _phoneController.text.trim().isEmpty,
        opensAt: _normalizeTime(_opensAtController.text),
        clearOpensAt: branch != null && _opensAtController.text.trim().isEmpty,
        closesAt: _normalizeTime(_closesAtController.text),
        clearClosesAt:
            branch != null && _closesAtController.text.trim().isEmpty,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  /// Accepts "HH:mm" or "HH:mm:ss" and returns the form the database wants.
  String? _normalizeTime(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    if (value.contains(':')) {
      final parts = value.split(':');
      if (parts.length == 2) return '$value:00';
      return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final branch = widget.initialBranch;

    return AlertDialog(
      title: Text(branch != null ? S.editBranch : S.addBranch),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.md),
                  child: Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      decoration: InputDecoration(labelText: S.branchCode),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(labelText: S.branchPhone),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              TextField(
                controller: _nameArController,
                decoration: InputDecoration(labelText: '${S.nameAr} *'),
                textDirection: TextDirection.rtl,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: AppDimensions.md),
              TextField(
                controller: _nameEnController,
                decoration: InputDecoration(labelText: S.nameEn),
              ),
              const SizedBox(height: AppDimensions.md),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(labelText: S.branchAddress),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: AppDimensions.md),
              AdminLocationPicker(
                initialLatitude: _pickedLatitude,
                initialLongitude: _pickedLongitude,
                initialAddress: _addressController.text,
                onAddressChanged: (address) => _addressController.text = address,
                onPicked: (point, address) {
                  _pickedLatitude = point.latitude;
                  _pickedLongitude = point.longitude;
                  if (address != null && address.isNotEmpty) {
                    _addressController.text = address;
                  }
                  setState(() {});
                },
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _opensAtController,
                      decoration: InputDecoration(
                        labelText: S.opensAt,
                        hintText: 'HH:mm',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: TextField(
                      controller: _closesAtController,
                      decoration: InputDecoration(
                        labelText: S.closesAt,
                        hintText: 'HH:mm',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: AppDimensions.spinnerSize,
                  height: AppDimensions.spinnerSize,
                  child: CircularProgressIndicator(
                    strokeWidth: AppDimensions.spinnerStroke,
                  ),
                )
              : Text(S.save),
        ),
      ],
    );
  }
}
