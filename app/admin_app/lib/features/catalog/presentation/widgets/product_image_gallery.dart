import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/services/admin_image_picker.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/catalog/admin_product_exception.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_dialogs.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_image_editor.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_image_settings.dart';

/// The gallery of the pictures of one product.
///
/// It shows every picture of the product, a large preview of the selected
/// one and the actions that belong to it. The gallery never writes by
/// itself: every action is handed to the page, which owns the repository
/// and the state of the product.
class ProductImageGallery extends StatefulWidget {
  const ProductImageGallery({
    super.key,
    required this.images,
    required this.onAdd,
    required this.onReplace,
    required this.onDelete,
    required this.onSetPrimary,
    this.onEdit,
    this.onApplySettings,
    this.onPickPicture,
    this.onReload,
  });

  final List<AdminProductImage> images;

  /// Picks a picture from the device of the admin.
  ///
  /// The gallery uses the picker of the platform; a caller (a test) can give
  /// its own.
  final Future<ProductImageSource?> Function()? onPickPicture;

  /// Reads the pictures of the product again after a failed action.
  final Future<List<AdminProductImage>> Function()? onReload;

  /// Adds a picture from the device or from a link and returns the new list.
  final Future<List<AdminProductImage>> Function(
    ProductImageSource source,
    void Function(AdminImageUploadPhase phase)? onPhase,
  )
  onAdd;

  /// Points a picture at another picture and returns the new list.
  final Future<List<AdminProductImage>> Function(
    AdminProductImage image,
    ProductImageSource source,
    void Function(AdminImageUploadPhase phase)? onPhase,
  )
  onReplace;

  /// Removes a picture and returns the new list.
  final Future<List<AdminProductImage>> Function(AdminProductImage image)
  onDelete;

  /// Makes a picture the primary one and returns the new list.
  final Future<List<AdminProductImage>> Function(AdminProductImage image)
  onSetPrimary;

  /// Opens the editor of a picture: the file is cut, turned and written
  /// again, and the new list comes back.
  final Future<List<AdminProductImage>> Function(
    AdminProductImage image,
    Uint8List bytes,
    String fileName,
  )?
  onEdit;

  /// Applies the display settings of a picture, or of every picture of the
  /// product.
  final Future<List<AdminProductImage>> Function({
    required AdminProductImage image,
    required BoxFit fit,
    required Alignment alignment,
    required ImageSettingsScope scope,
  })?
  onApplySettings;

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

/// A picture that is on its way to the product.
class _PendingPicture {
  const _PendingPicture({
    required this.source,
    required this.phase,
    this.replaces,
  });

  final ProductImageSource source;

  /// The step of the write that is running.
  final AdminImageUploadPhase phase;

  /// The picture the new one replaces, when the picture is a replacement.
  final AdminProductImage? replaces;

  Uint8List? get bytes => source.bytes;
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  late List<AdminProductImage> _images = _orderedPictures(widget.images);
  String? _selectedId;
  bool _busy = false;
  String? _error;
  _PendingPicture? _pending;

  @override
  void didUpdateWidget(covariant ProductImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.images, widget.images)) return;
    // The gallery was given new pictures: they are shown in the same order,
    // with the primary one first.
    setState(() {
      _images = _orderedPictures(widget.images);
      final selected = _selected;
      _selectedId = selected?.id;
    });
  }

  AdminProductImage? get _selected {
    if (_images.isEmpty) return null;
    for (final image in _images) {
      if (image.id == _selectedId) return image;
    }
    return _images.first;
  }

  void _apply(List<AdminProductImage> images) {
    setState(() {
      _images = _orderedPictures(images);
      _error = null;
      _busy = false;
      _pending = null;
      final selected = _selected;
      _selectedId = selected?.id;
    });
  }

  /// Runs an action and keeps the gallery in step with the product.
  Future<void> _run(Future<List<AdminProductImage>> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _apply(await action());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pending = null;
        _error = _messageFor(error);
      });
      // The gallery shows the pictures that are really in the database, not
      // the ones the failed action left behind.
      await _reload();
    }
  }

  /// Reads the pictures of the product again, after a failure.
  Future<void> _reload() async {
    final onReload = widget.onReload;
    if (onReload == null) return;

    try {
      final images = await onReload();
      if (!mounted) return;
      setState(() {
        _images = _orderedPictures(images);
        final selected = _selected;
        _selectedId = selected?.id;
      });
    } catch (_) {
      // The pictures that are shown stay as they are.
    }
  }

  String _messageFor(Object error) {
    if (error is AdminProductException) return error.message;
    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      if (message.contains('permission')) return S.imageActionForbidden;
      // The database does not know the settings yet: the migration that adds
      // them is missing, and the admin deserves to know it.
      if (message.contains('column') || error.code == 'PGRST204') {
        return S.imageSettingsMissing;
      }
    }
    return S.imageActionFailed;
  }

  Future<void> _addImage() async {
    final source = await _askForSource('');
    if (source == null || !mounted) return;
    await _write(
      () => widget.onAdd(source, _onPhase),
      source: source,
      replaces: null,
    );
  }

  Future<void> _replaceImage(AdminProductImage image) async {
    final source = await _askForSource(image.imageUrl);
    if (source == null || !mounted) return;
    await _write(
      () => widget.onReplace(image, source, _onPhase),
      source: source,
      replaces: image,
    );
  }

  /// Writes a picture and shows its steps while they run.
  Future<void> _write(
    Future<List<AdminProductImage>> Function() action, {
    required ProductImageSource source,
    required AdminProductImage? replaces,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      // The picture the admin picked is shown right away, with the step it
      // is in. It is not a picture of the product yet.
      _pending = _PendingPicture(
        source: source,
        phase: AdminImageUploadPhase.uploading,
        replaces: replaces,
      );
    });
    try {
      _apply(await action());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pending = null;
        _error = _messageFor(error);
      });
      await _reload();
    }
  }

  /// Remembers the step of the write that is running.
  void _onPhase(AdminImageUploadPhase phase) {
    if (!mounted) return;
    final pending = _pending;
    if (pending == null) return;
    setState(() {
      _pending = _PendingPicture(
        source: pending.source,
        phase: phase,
        replaces: pending.replaces,
      );
    });
  }

  /// Opens the editor of a picture.
  ///
  /// The picture is cut, turned and written again as a new file. The file
  /// that is already saved stays as it is until the new one is written.
  Future<void> _editImage(AdminProductImage image) async {
    if (_busy) return;
    final bytes = await _readImage(image.imageUrl);
    if (bytes == null || !mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => ProductImageEditor(
        imageUrl: image.imageUrl,
        fileName: _fileNameOf(image),
        onSave: (result) async {
          final onEdit = widget.onEdit;
          if (onEdit == null) return;
          await onEdit(image, result.bytes, result.fileName);
        },
      ),
    );

    if (!mounted) return;
    await _reload();
  }

  /// Opens the display settings of a picture.
  Future<void> _openSettings(AdminProductImage image) async {
    if (_busy) return;
    await showDialog<void>(
      context: context,
      builder: (context) => ProductImageSettings(
        image: image,
        imageCount: _images.length,
        onApply: ({required fit, required alignment, required scope}) async {
          final onApplySettings = widget.onApplySettings;
          if (onApplySettings == null) return;
          await onApplySettings(
            image: image,
            fit: fit,
            alignment: alignment,
            scope: scope,
          );
        },
      ),
    );

    if (!mounted) return;
    await _reload();
  }

  /// The file of a picture, read from its url.
  Future<Uint8List?> _readImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  /// The name of the file of a picture.
  String _fileNameOf(AdminProductImage image) {
    final name = image.imageUrl.split('/').last;
    if (name.isEmpty) return 'picture.png';
    return name.contains('.') ? name : '$name.png';
  }

  Future<void> _deleteImage(AdminProductImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.deleteImage),
        content: Text(S.deleteImageConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(S.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => widget.onDelete(image));
  }

  /// Asks the admin where the picture comes from: a file of the device or a
  /// link that is already hosted somewhere.
  Future<ProductImageSource?> _askForSource(String initialValue) async {
    final choice = await showDialog<_ImageChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.imageSource),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.imageAdd01, size: 20),
              title: Text(S.uploadFromDevice),
              onTap: () => Navigator.of(context).pop(_ImageChoice.device),
            ),
            ListTile(
              leading: const Icon(AppIcons.link01, size: 20),
              title: Text(S.useImageLink),
              onTap: () => Navigator.of(context).pop(_ImageChoice.link),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.cancel),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return null;

    if (choice == _ImageChoice.link) {
      final url = await _askForUrl(initialValue);
      if (url == null || url.trim().isEmpty) return null;
      return ProductImageSource.link(url.trim());
    }

    return _pickFromDevice();
  }

  /// Picks a picture from the device of the admin.
  Future<ProductImageSource?> _pickFromDevice() async {
    final onPick = widget.onPickPicture;
    if (onPick != null) return onPick();

    try {
      return await pickAdminImage();
    } catch (error) {
      if (!mounted) return null;
      setState(() => _error = _messageFor(error));
      return null;
    }
  }

  Future<String?> _askForUrl(String initialValue) {
    return showDialog<String>(
      context: context,
      builder: (context) => ImageUrlDialog(initialValue: initialValue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final isNarrow = size.width < AppBreakpoints.imageWorkspace;
    final dialogWidth = isNarrow ? size.width - 32 : 820.0;
    final dialogHeight = (size.height * 0.85).clamp(420.0, 780.0);
    final selected = _selected;

    return AlertDialog(
      title: Text(S.productImages),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColor.errorColor,
                  ),
                ),
              ),
            Expanded(
              child: _images.isEmpty && _pending == null
                  ? Center(child: Text(S.noImagesYet))
                  : isNarrow
                  ? _narrowLayout(selected)
                  : _wideLayout(selected),
            ),
            const SizedBox(height: AppSpacing.md),
            _Actions(
              image: selected,
              busy: _busy,
              onAdd: _addImage,
              onReplace: selected == null
                  ? null
                  : () => _replaceImage(selected),
              onEdit: selected == null || widget.onEdit == null
                  ? null
                  : () => _editImage(selected),
              onSettings: selected == null
                  ? null
                  : () => _openSettings(selected),
              onDelete: selected == null ? null : () => _deleteImage(selected),
              onSetPrimary: selected == null || selected.isPrimary
                  ? null
                  : () => _run(() => widget.onSetPrimary(selected)),
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

  /// The large picture beside a column of small ones.
  Widget _wideLayout(AdminProductImage? selected) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _Preview(image: selected)),
        const SizedBox(width: AppSpacing.lg),
        SizedBox(
          width: 104,
          child: _Thumbnails(
            images: _images,
            pending: _pending,
            selectedId: selected?.id,
            onSelect: (id) => setState(() => _selectedId = id),
          ),
        ),
      ],
    );
  }

  /// The small screens: the picture on top, the pictures under it.
  Widget _narrowLayout(AdminProductImage? selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _Preview(image: selected)),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: AppDimensions.imageThumbnailTileSize,
          child: _Thumbnails(
            images: _images,
            pending: _pending,
            selectedId: selected?.id,
            onSelect: (id) => setState(() => _selectedId = id),
            horizontal: true,
          ),
        ),
      ],
    );
  }
}

/// Where the admin takes the picture from.
enum _ImageChoice { device, link }

/// The pictures in the order they are shown.
///
/// The primary picture is always first, the others keep the order of the
/// database (`sort_order`) and the identifier breaks a tie, so the order
/// never depends on the order the rows arrive in.
List<AdminProductImage> _orderedPictures(List<AdminProductImage> images) {
  final primary = <AdminProductImage>[];
  final others = <AdminProductImage>[];

  for (final image in images) {
    if (image.isPrimary) {
      primary.add(image);
    } else {
      others.add(image);
    }
  }

  others.sort((a, b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    if (byOrder != 0) return byOrder;
    return a.id.compareTo(b.id);
  });

  return <AdminProductImage>[...primary, ...others];
}

/// The large picture the admin is looking at.
class _Preview extends StatelessWidget {
  const _Preview({required this.image});

  final AdminProductImage? image;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = this.image;

    if (image == null) {
      return Container(
        decoration: BoxDecoration(
          color: AppColor.recordCellBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        alignment: Alignment.center,
        child: Text(
          S.noImagesYet,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColor.greyColor,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColor.recordCellBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: image.imageUrl,
        fit: image.fit,
        alignment: image.alignment,
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
        errorWidget: (context, url, error) => Center(
          child: Icon(AppIcons.image01, size: 40, color: AppColor.greyColor),
        ),
      ),
    );
  }
}

/// The small pictures of the product, one under the other.
class _Thumbnails extends StatelessWidget {
  const _Thumbnails({
    required this.images,
    required this.pending,
    required this.selectedId,
    required this.onSelect,
    this.horizontal = false,
  });

  final List<AdminProductImage> images;

  /// The picture that is on its way to the product.
  final _PendingPicture? pending;

  final String? selectedId;
  final ValueChanged<String> onSelect;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];

    // A picture that is being written takes the place of the picture it
    // replaces, or joins the list when it is a new one.
    if (pending != null) {
      tiles.add(
        _PendingTile(
          pending: pending!,
          onSelect: pending!.replaces == null
              ? null
              : () => onSelect(pending!.replaces!.id),
        ),
      );
    }

    for (final image in images) {
      if (pending?.replaces?.id == image.id) continue;
      tiles.add(
        _Thumbnail(
          image: image,
          isSelected: image.id == selectedId,
          onTap: () => onSelect(image.id),
        ),
      );
    }

    if (horizontal) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => SizedBox(
          width: AppDimensions.imageThumbnailTileSize,
          child: tiles[index],
        ),
      );
    }

    return ListView.separated(
      itemCount: tiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => tiles[index],
    );
  }
}

/// A small picture of the product.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.image,
    required this.isSelected,
    required this.onTap,
  });

  final AdminProductImage image;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        height: AppDimensions.imageThumbnailTileSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? AppColor.primaryColor : AppColor.recordBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: image.imageUrl,
              fit: image.fit,
              alignment: image.alignment,
              placeholder: (context, url) =>
                  const ColoredBox(color: AppColor.recordCellBackground),
              errorWidget: (context, url, error) => const ColoredBox(
                color: AppColor.recordCellBackground,
                child: Icon(
                  AppIcons.image01,
                  size: 20,
                  color: AppColor.greyColor,
                ),
              ),
            ),
            if (image.isPrimary) const _PrimaryBadge(),
          ],
        ),
      ),
    );
  }
}

/// The mark of the picture that is the primary one.
class _PrimaryBadge extends StatelessWidget {
  const _PrimaryBadge();

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: 4,
      start: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: AppColor.primaryColor,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          S.primary,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColor.whiteColor,
            fontSize: AppFontSizes.size10,
          ),
        ),
      ),
    );
  }
}

/// The picture that is on its way to the product.
///
/// It shows the file the admin picked, with a layer over it that tells which
/// step of the write is running.
class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.pending, this.onSelect});

  final _PendingPicture pending;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = pending.bytes;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        height: AppDimensions.imageThumbnailTileSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColor.primaryColor, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(
                bytes,
                fit: BoxFit.fill,
                cacheWidth: AppDimensions.imagePreviewCacheWidth.round(),
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: AppColor.recordCellBackground),
              )
            else
              const ColoredBox(color: AppColor.recordCellBackground),
            // The layer over the picture: the picture is not saved yet.
            ColoredBox(
              color: AppColor.whiteColor.withValues(alpha: 0.72),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: AppDimensions.spinnerSize,
                      height: AppDimensions.spinnerSize,
                      child: CircularProgressIndicator(
                        strokeWidth: AppDimensions.spinnerStroke,
                        color: AppColor.primaryColor,
                      ),
                    ),
                    const SizedBox(height: AppSizes.px4),
                    Text(
                      pending.phase == AdminImageUploadPhase.uploading
                          ? S.uploadingImage
                          : S.savingImage,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColor.primaryColor,
                        fontSize: AppFontSizes.size10,
                        fontWeight: AppFontWeights.semiBold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The actions that belong to the selected picture.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.image,
    required this.busy,
    required this.onAdd,
    required this.onReplace,
    required this.onEdit,
    required this.onSettings,
    required this.onDelete,
    required this.onSetPrimary,
  });

  final AdminProductImage? image;
  final bool busy;
  final VoidCallback onAdd;
  final VoidCallback? onReplace;
  final VoidCallback? onEdit;
  final VoidCallback? onSettings;
  final VoidCallback? onDelete;
  final VoidCallback? onSetPrimary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton.icon(
          onPressed: busy ? null : onAdd,
          icon: const Icon(AppIcons.add01, size: 18),
          label: Text(S.addImage),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onReplace,
          icon: const Icon(AppIcons.imageAdd01, size: 18),
          label: Text(S.replaceImage),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onSetPrimary,
          icon: const Icon(AppIcons.tick01, size: 18),
          label: Text(S.setPrimaryImage),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onEdit,
          icon: const Icon(AppIcons.edit01, size: 18),
          label: Text(S.editImage),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onSettings,
          icon: const Icon(AppIcons.settings01, size: 18),
          label: Text(S.imageSettings),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onDelete,
          icon: const Icon(AppIcons.delete01, size: 18),
          label: Text(S.delete),
          style: OutlinedButton.styleFrom(foregroundColor: AppColor.errorColor),
        ),
      ],
    );
  }
}
