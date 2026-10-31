import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/services/admin_image_picker.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/branches/domain/entities/admin_branch_exception.dart';
import 'package:admin_app/features/branches/domain/entities/branch_mutation_outcome.dart';
import 'package:admin_app/features/branches/presentation/manager/admin_branch_cubit.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_messages.dart';

/// Opens the dialog that replaces or removes the picture of a branch.
Future<bool?> showBranchImageDialog({
  required BuildContext context,
  required AdminBranchCubit cubit,
  required String branchId,
  required String? imageUrl,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => BranchImageDialog(
      currentImageUrl: imageUrl,
      onApply: (source) async {
        final outcome = source.isLink
            ? await cubit.updateBranchImage(branchId, source.url)
            : await cubit.uploadBranchImage(
                branchId: branchId,
                bytes: source.bytes!,
                fileName: source.fileName!,
                contentType: source.contentType!,
              );
        if (outcome != BranchMutationOutcome.success) {
          throw AdminBranchException(branchMutationErrorMessage(outcome));
        }
      },
      onRemove: () async {
        final outcome = await cubit.updateBranchImage(branchId, null);
        if (outcome != BranchMutationOutcome.success) {
          throw AdminBranchException(branchMutationErrorMessage(outcome));
        }
        await cubit.deleteBranchImageFile(imageUrl);
      },
    ),
  );
}

/// The dialog that changes the picture of a branch.
class BranchImageDialog extends StatefulWidget {
  const BranchImageDialog({
    super.key,
    required this.currentImageUrl,
    required this.onApply,
    this.onRemove,
    this.onPickPicture,
  });

  final String? currentImageUrl;
  final Future<void> Function(ProductImageSource source) onApply;
  final Future<void> Function()? onRemove;
  final Future<ProductImageSource?> Function()? onPickPicture;

  @override
  State<BranchImageDialog> createState() => _BranchImageDialogState();
}

class _BranchImageDialogState extends State<BranchImageDialog> {
  bool _busy = false;
  String? _phaseText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(S.branchesImageAction),
      content: SizedBox(
        width: AppDimensions.dialogBodyWidthPanel,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.currentImageUrl != null &&
                widget.currentImageUrl!.trim().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: SizedBox(
                  width: double.infinity,
                  height: 260,
                  child: CachedNetworkImage(
                    imageUrl: widget.currentImageUrl!,
                    fit: BoxFit.fill,
                    errorWidget: (_, _, _) => const ColoredBox(
                      color: AppColor.secondaryColor,
                      child: Center(child: Icon(AppIcons.imageAdd01)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_busy) ...[
              const Center(child: CircularProgressIndicator()),
              if (_phaseText != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _phaseText!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColor.greyColor,
                  ),
                ),
              ],
            ] else ...[
              ListTile(
                leading: const Icon(AppIcons.imageAdd01, size: 20),
                title: Text(S.uploadFromDevice),
                subtitle: Text(
                  S.imageFormats,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColor.greyColor,
                  ),
                ),
                onTap: _busy ? null : _pickFromDevice,
              ),
              ListTile(
                leading: const Icon(AppIcons.link01, size: 20),
                title: Text(S.useImageLink),
                onTap: _busy ? null : _askForLink,
              ),
              if (widget.currentImageUrl != null &&
                  widget.currentImageUrl!.isNotEmpty &&
                  widget.onRemove != null) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(
                    AppIcons.delete01,
                    size: 20,
                    color: AppColor.errorColor,
                  ),
                  title: Text(
                    S.deleteImage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColor.errorColor,
                    ),
                  ),
                  onTap: _busy ? null : _removeImage,
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
      ],
    );
  }

  Future<void> _pickFromDevice() async {
    final source = await widget.onPickPicture?.call();
    if (source != null) {
      await _apply(source);
      return;
    }

    try {
      final picked = await pickAdminImage();
      if (picked == null) return;
      await _apply(picked);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        adminErrorMessage(error, fallback: S.imageCouldNotBeOpened),
        isError: true,
      );
    }
  }

  Future<void> _askForLink() async {
    final controller = TextEditingController(
      text: widget.currentImageUrl ?? '',
    );
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.useImageLink),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: S.imageUrl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(S.save),
          ),
        ],
      ),
    );
    if (url == null || url.trim().isEmpty) return;
    await _apply(ProductImageSource.link(url.trim()));
  }

  Future<void> _apply(ProductImageSource source) async {
    setState(() {
      _busy = true;
      _phaseText = source.isLink ? S.savingImage : S.uploadingImage;
    });

    try {
      await widget.onApply(source);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _phaseText = null;
      });
      _showMessage(adminErrorMessage(error), isError: true);
    }
  }

  Future<void> _removeImage() async {
    final remove = widget.onRemove;
    if (remove == null || _busy) return;
    setState(() {
      _busy = true;
      _phaseText = S.savingImage;
    });
    try {
      await remove();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _phaseText = null;
      });
      _showMessage(adminErrorMessage(error), isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColor.errorColor : null,
      ),
    );
  }
}
