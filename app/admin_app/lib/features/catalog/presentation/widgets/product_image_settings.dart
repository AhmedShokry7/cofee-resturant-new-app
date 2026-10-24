import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/catalog/data/models/admin_product_image.dart';

/// Who the display settings of a picture are applied to.
enum ImageSettingsScope {
  /// Only the picture the admin is looking at.
  thisPicture,

  /// Every picture of the product.
  allPictures,
}

/// The display settings of a picture.
///
/// The settings say how a picture fills its space and where it sits in it.
/// They never change the file of the picture, so a change of the settings can
/// always be undone.
class ProductImageSettings extends StatefulWidget {
  const ProductImageSettings({
    super.key,
    required this.image,
    required this.imageCount,
    required this.onApply,
  });

  /// The picture the settings belong to.
  final AdminProductImage image;

  /// How many pictures the product has.
  final int imageCount;

  /// Applies the settings. The scope tells the caller who they are for.
  final Future<void> Function({
    required BoxFit fit,
    required Alignment alignment,
    required ImageSettingsScope scope,
  })
  onApply;

  @override
  State<ProductImageSettings> createState() => _ProductImageSettingsState();
}

class _ProductImageSettingsState extends State<ProductImageSettings> {
  late BoxFit _fit = widget.image.fit;
  late Alignment _alignment = widget.image.alignment;
  ImageSettingsScope _scope = ImageSettingsScope.thisPicture;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final isNarrow = size.width < 640;

    return AlertDialog(
      title: Text(S.imageSettings),
      content: SizedBox(
        width: isNarrow ? size.width - 32 : 620,
        height: isNarrow ? size.height * 0.7 : 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.md),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColor.errorColor,
                  ),
                ),
              ),
            _Preview(
              imageUrl: widget.image.imageUrl,
              fit: _fit,
              alignment: _alignment,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(S.imageFit, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppDimensions.sm),
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: [
                for (final fit in imageFitOptions)
                  ChoiceChip(
                    label: Text(fit.name),
                    selected: fit == _fit,
                    onSelected: (_) => setState(() => _fit = fit),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            Text(S.imageAlignment, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppDimensions.sm),
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: [
                for (final alignment in imageAlignmentOptions)
                  ChoiceChip(
                    label: Text(alignmentName(alignment)),
                    selected:
                        alignmentName(alignment) == alignmentName(_alignment),
                    onSelected: (_) => setState(() => _alignment = alignment),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            Text(S.imageScope, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppDimensions.sm),
            RadioGroup<ImageSettingsScope>(
              groupValue: _scope,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _scope = value);
              },
              child: Column(
                children: [
                  RadioListTile<ImageSettingsScope>(
                    value: ImageSettingsScope.thisPicture,
                    title: Text(S.applyToThisImage),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  RadioListTile<ImageSettingsScope>(
                    value: ImageSettingsScope.allPictures,
                    title: Text(S.applyToAllImages),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    enabled: widget.imageCount > 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _apply,
          child: _saving
              ? const SizedBox(
                  width: AppDimensions.spinnerSize,
                  height: AppDimensions.spinnerSize,
                  child: CircularProgressIndicator(
                    strokeWidth: AppDimensions.spinnerStroke,
                    color: AppColor.whiteColor,
                  ),
                )
              : Text(S.save),
        ),
      ],
    );
  }

  /// Applies the settings, after the admin confirms a change that touches
  /// every picture of the product.
  Future<void> _apply() async {
    if (_saving) return;

    if (_scope == ImageSettingsScope.allPictures) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(S.applyToAllImages),
          content: Text(S.applyToAllImagesConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(S.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(S.save),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onApply(fit: _fit, alignment: _alignment, scope: _scope);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = S.imageActionFailed;
      });
    }
  }
}

/// The picture as it will be shown with the chosen settings.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.imageUrl,
    required this.fit,
    required this.alignment,
  });

  final String imageUrl;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColor.recordCellBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        alignment: alignment,
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: AppDimensions.spinnerSizeLg,
            height: AppDimensions.spinnerSizeLg,
            child: CircularProgressIndicator(
              strokeWidth: AppDimensions.spinnerStroke,
              color: AppColor.primaryColor,
            ),
          ),
        ),
        errorWidget: (context, url, error) =>
            const Icon(Icons.image_not_supported, color: AppColor.greyColor),
      ),
    );
  }
}
