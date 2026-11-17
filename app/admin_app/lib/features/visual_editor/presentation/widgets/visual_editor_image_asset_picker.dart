import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/services/admin_image_picker.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/visual_editor/data/visual_editor_image_asset_repository.dart';
import 'package:admin_app/shared/widgets/category_image_dialog.dart';

Future<String?> showVisualEditorImageAssetPicker({
  required BuildContext context,
  required VisualEditorImageAssetRepository repository,
  required Set<String> permissions,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ImageAssetPickerDialog(
      repository: repository,
      permissions: permissions,
    ),
  );
}

class _ImageAssetPickerDialog extends StatefulWidget {
  const _ImageAssetPickerDialog({
    required this.repository,
    required this.permissions,
  });

  final VisualEditorImageAssetRepository repository;
  final Set<String> permissions;

  @override
  State<_ImageAssetPickerDialog> createState() =>
      _ImageAssetPickerDialogState();
}

class _ImageAssetPickerDialogState extends State<_ImageAssetPickerDialog> {
  late Future<List<VisualEditorImageAsset>> _assets;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _assets = _load();
  }

  Future<List<VisualEditorImageAsset>> _load() => widget.repository.loadAssets(
    includePlans: widget.permissions.contains('subscriptions.manage'),
  );

  void _reload() => setState(() => _assets = _load());

  bool _canManage(VisualEditorImageAsset asset) => switch (asset.kind) {
    VisualEditorImageAssetKind.product || VisualEditorImageAssetKind.bundle =>
      widget.permissions.contains('catalog.product.write'),
    VisualEditorImageAssetKind.category => widget.permissions.contains(
      'catalog.category.write',
    ),
    VisualEditorImageAssetKind.banner => widget.permissions.contains(
      'settings.write',
    ),
    VisualEditorImageAssetKind.plan => widget.permissions.contains(
      'subscriptions.manage',
    ),
  };

  String _kindName(VisualEditorImageAssetKind kind) => switch (kind) {
    VisualEditorImageAssetKind.product => S.products,
    VisualEditorImageAssetKind.category => S.categories,
    VisualEditorImageAssetKind.banner => S.banners,
    VisualEditorImageAssetKind.bundle => S.bundles,
    VisualEditorImageAssetKind.plan => S.subscriptionPlans,
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.visualEditorImageLibraryTitle),
      content: SizedBox(
        width: 680,
        height: 560,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(AppIcons.search01),
                hintText: S.visualEditorImageLibrarySearch,
                suffixIcon: IconButton(
                  tooltip: S.refresh,
                  onPressed: _reload,
                  icon: const Icon(AppIcons.refresh),
                ),
              ),
              onChanged: (value) => setState(() => _filter = value.trim()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<VisualEditorImageAsset>>(
                future: _assets,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(S.visualEditorImageLibraryLoadFailed),
                          TextButton(onPressed: _reload, child: Text(S.retry)),
                        ],
                      ),
                    );
                  }
                  final assets =
                      (snapshot.data ?? const <VisualEditorImageAsset>[])
                          .where((asset) {
                            final term = _filter.toLowerCase();
                            return term.isEmpty ||
                                asset.label.toLowerCase().contains(term) ||
                                _kindName(asset.kind)
                                    .toLowerCase()
                                    .contains(term);
                          })
                          .toList(growable: false);
                  if (assets.isEmpty) {
                    return Center(child: Text(S.visualEditorImageLibraryEmpty));
                  }
                  return ListView.separated(
                    itemCount: assets.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _assetTile(assets[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
      ],
    );
  }

  Widget _assetTile(VisualEditorImageAsset asset) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 48,
          child: CachedNetworkImage(
            imageUrl: asset.imageUrl,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => const ColoredBox(
              color: AppColor.recordCellBackground,
              child: Icon(AppIcons.image01),
            ),
          ),
        ),
      ),
      title: Text(asset.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_kindName(asset.kind)),
      onTap: () => Navigator.of(context).pop(asset.imageUrl),
      trailing: _canManage(asset)
          ? PopupMenuButton<_AssetAction>(
              tooltip: S.visualEditorImageManage,
              onSelected: (action) => _manage(asset, action),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _AssetAction.replace,
                  child: ListTile(
                    leading: const Icon(AppIcons.imageAdd01),
                    title: Text(S.replaceImage),
                  ),
                ),
                PopupMenuItem(
                  value: _AssetAction.remove,
                  child: ListTile(
                    leading: const Icon(AppIcons.delete01),
                    title: Text(S.deleteImage),
                  ),
                ),
              ],
            )
          : const Icon(Icons.chevron_right),
    );
  }

  Future<void> _manage(
    VisualEditorImageAsset asset,
    _AssetAction action,
  ) async {
    if (action == _AssetAction.remove) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(S.deleteImage),
          content: Text(S.visualEditorImageRemoveConfirm(asset.label)),
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
      try {
        await widget.repository.removeImage(asset);
        _reload();
      } catch (error) {
        _showError(error);
      }
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => CategoryImageDialog(
        currentImageUrl: asset.imageUrl,
        onPickPicture: pickAdminImage,
        onApply: (source) async {
          await widget.repository.replaceImage(asset, source);
          _reload();
        },
        onRemove: () async {
          await widget.repository.removeImage(asset);
          _reload();
        },
      ),
    );
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$error')));
  }
}

enum _AssetAction { replace, remove }
