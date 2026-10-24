import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/banners/data/models/admin_banner.dart';
import 'package:admin_app/features/banners/presentation/manager/admin_banner_cubit.dart';
import 'package:admin_app/features/catalog/data/models/admin_product_image.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';
import 'package:admin_app/features/catalog/data/models/admin_category.dart';
import 'package:admin_app/features/catalog/presentation/widgets/category_image_dialog.dart';

/// Opens the dialog that writes a new banner through the cubit of the page.
Future<void> showBannerCreateDialog({
  required BuildContext context,
  required AdminBannerCubit cubit,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => BannerDataDialog(
      cubit: cubit,
      onSave: (banner) => cubit.createBanner(banner),
    ),
  );
}

/// Opens the dialog that writes the edited banner through the cubit of the
/// page.
Future<void> showBannerEditDialog({
  required BuildContext context,
  required AdminBannerCubit cubit,
  required AdminBanner banner,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => BannerDataDialog(
      cubit: cubit,
      initialBanner: banner,
      onSave: (updated) => cubit.updateBanner(updated),
    ),
  );
}

class BannerDataDialog extends StatefulWidget {
  const BannerDataDialog({
    super.key,
    required this.onSave,
    this.initialBanner,
    this.cubit,
  });

  final Future<void> Function(AdminBanner banner) onSave;
  final AdminBanner? initialBanner;
  final AdminBannerCubit? cubit;

  @override
  State<BannerDataDialog> createState() => _BannerDataDialogState();
}

class _BannerDataDialogState extends State<BannerDataDialog> {
  late final TextEditingController _titleArController;
  late final TextEditingController _titleEnController;
  late final TextEditingController _subtitleArController;
  late final TextEditingController _subtitleEnController;
  late final TextEditingController _descriptionArController;
  late final TextEditingController _descriptionEnController;
  late final TextEditingController _ctaArController;
  late final TextEditingController _ctaEnController;
  late final TextEditingController _targetTypeController;
  late final TextEditingController _targetIdController;
  late final TextEditingController _targetUrlController;
  late final TextEditingController _sortOrderController;

  late final AdminBannerCubit _cubit;
  String? _imageUrl;
  bool _isPublished = true;
  bool _saving = false;
  String? _error;
  List<AdminProduct> _products = const <AdminProduct>[];
  List<AdminCategory> _categories = const <AdminCategory>[];
  bool _loadingTargets = true;

  @override
  void initState() {
    super.initState();
    _cubit = widget.cubit ?? AdminBannerCubit();
    final b = widget.initialBanner;
    _titleArController = TextEditingController(text: b?.titleAr ?? '');
    _titleEnController = TextEditingController(text: b?.titleEn ?? '');
    _subtitleArController = TextEditingController(text: b?.subtitleAr ?? '');
    _subtitleEnController = TextEditingController(text: b?.subtitleEn ?? '');
    _descriptionArController = TextEditingController(
      text: b?.descriptionAr ?? '',
    );
    _descriptionEnController = TextEditingController(
      text: b?.descriptionEn ?? '',
    );
    _ctaArController = TextEditingController(text: b?.ctaLabelAr ?? '');
    _ctaEnController = TextEditingController(text: b?.ctaLabelEn ?? '');
    _targetTypeController = TextEditingController(
      text: b?.targetType ?? 'none',
    );
    _targetIdController = TextEditingController(text: b?.targetId ?? '');
    _targetUrlController = TextEditingController(text: b?.targetUrl ?? '');
    _sortOrderController = TextEditingController(
      text: b?.sortOrder.toString() ?? '0',
    );
    _imageUrl = b?.imageUrl;
    _isPublished = b?.isPublished ?? true;
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    try {
      final snapshot = await AdminProductRepository().loadCatalog();
      if (!mounted) return;
      setState(() {
        _products = snapshot.products;
        _categories = snapshot.categories;
        _loadingTargets = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingTargets = false);
    }
  }

  @override
  void dispose() {
    _titleArController.dispose();
    _titleEnController.dispose();
    _subtitleArController.dispose();
    _subtitleEnController.dispose();
    _descriptionArController.dispose();
    _descriptionEnController.dispose();
    _ctaArController.dispose();
    _ctaEnController.dispose();
    _targetTypeController.dispose();
    _targetIdController.dispose();
    _targetUrlController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  void _changeImage() {
    showDialog<void>(
      context: context,
      builder: (context) => CategoryImageDialog(
        currentImageUrl: _imageUrl,
        onApply: _applyImage,
        onRemove: _removeImage,
      ),
    );
  }

  Future<void> _applyImage(ProductImageSource source) async {
    try {
      String url;
      if (source.isLink) {
        url = source.url!;
        if (widget.initialBanner != null) {
          await _cubit.updateBannerImage(widget.initialBanner!.id, url);
        }
      } else {
        url = await _cubit.uploadBannerImage(
          bannerId: widget.initialBanner?.id,
          bytes: source.bytes!,
          fileName: source.fileName!,
          contentType: source.contentType!,
        );
      }
      if (!mounted) return;
      setState(() => _imageUrl = url);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  void _removeImage() {
    final current = _imageUrl;
    if (widget.initialBanner != null && current != null) {
      _cubit.deleteBannerImageFile(current);
      _cubit.updateBannerImage(widget.initialBanner!.id, null);
    }
    setState(() => _imageUrl = null);
  }

  void _submit() async {
    if (_saving) return;
    final titleAr = _titleArController.text.trim();
    final titleEn = _titleEnController.text.trim();
    if (titleAr.isEmpty || titleEn.isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    if (_imageUrl == null || _imageUrl!.trim().isEmpty) {
      setState(() => _error = 'Image is required');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final banner =
        (widget.initialBanner ??
                AdminBanner(
                  id: '',
                  titleAr: titleAr,
                  titleEn: titleEn,
                  imageUrl: _imageUrl!,
                  targetType: _targetTypeController.text.trim().isEmpty
                      ? 'none'
                      : _targetTypeController.text.trim(),
                ))
            .copyWith(
              titleAr: titleAr,
              titleEn: titleEn,
              subtitleAr: _subtitleArController.text.trim().isEmpty
                  ? null
                  : _subtitleArController.text.trim(),
              subtitleEn: _subtitleEnController.text.trim().isEmpty
                  ? null
                  : _subtitleEnController.text.trim(),
              descriptionAr: _descriptionArController.text.trim().isEmpty
                  ? null
                  : _descriptionArController.text.trim(),
              descriptionEn: _descriptionEnController.text.trim().isEmpty
                  ? null
                  : _descriptionEnController.text.trim(),
              imageUrl: _imageUrl!,
              ctaLabelAr: _ctaArController.text.trim().isEmpty
                  ? null
                  : _ctaArController.text.trim(),
              ctaLabelEn: _ctaEnController.text.trim().isEmpty
                  ? null
                  : _ctaEnController.text.trim(),
              targetType: _targetTypeController.text.trim().isEmpty
                  ? 'none'
                  : _targetTypeController.text.trim(),
              targetId: _targetIdController.text.trim().isEmpty
                  ? null
                  : _targetIdController.text.trim(),
              targetUrl: _targetUrlController.text.trim().isEmpty
                  ? null
                  : _targetUrlController.text.trim(),
              sortOrder: int.tryParse(_sortOrderController.text.trim()) ?? 0,
              isPublished: _isPublished,
            );

    try {
      await widget.onSave(banner);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialBanner != null ? S.editBanner : S.addBanner),
      content: SizedBox(
        width: 640,
        height: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.md),
                  child: Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColor.errorColor),
                  ),
                ),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    child: SizedBox(
                      width: 240,
                      height: 120,
                      child: _imageUrl != null && _imageUrl!.trim().isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _imageUrl!,
                              fit: BoxFit.fill,
                              errorWidget: (_, _, _) => const ColoredBox(
                                color: AppColor.secondaryColor,
                                child: Icon(HugeIcons.strokeRoundedImageAdd01),
                              ),
                            )
                          : const ColoredBox(
                              color: AppColor.secondaryColor,
                              child: Icon(HugeIcons.strokeRoundedImageAdd01),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _changeImage,
                      icon: const Icon(
                        HugeIcons.strokeRoundedImageAdd01,
                        size: 18,
                      ),
                      label: Text(S.changeImage),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _titleArController,
                      decoration: const InputDecoration(
                        labelText: 'Title (Arabic) *',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: TextField(
                      controller: _titleEnController,
                      decoration: const InputDecoration(
                        labelText: 'Title (English) *',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subtitleArController,
                      decoration: const InputDecoration(
                        labelText: 'Subtitle (Arabic)',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: TextField(
                      controller: _subtitleEnController,
                      decoration: const InputDecoration(
                        labelText: 'Subtitle (English)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctaArController,
                      decoration: const InputDecoration(
                        labelText: 'CTA (Arabic)',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: TextField(
                      controller: _ctaEnController,
                      decoration: const InputDecoration(
                        labelText: 'CTA (English)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              DropdownButtonFormField<String>(
                initialValue: _targetTypeController.text.isEmpty
                    ? 'none'
                    : _targetTypeController.text,
                decoration: const InputDecoration(labelText: 'Target type'),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('None')),
                  DropdownMenuItem(value: 'product', child: Text('Product')),
                  DropdownMenuItem(value: 'category', child: Text('Category')),
                  DropdownMenuItem(value: 'url', child: Text('URL')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _targetTypeController.text = value;
                    _targetIdController.text = '';
                  });
                },
              ),
              const SizedBox(height: AppDimensions.md),
              if (_targetTypeController.text == 'product')
                _loadingTargets
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<String>(
                        initialValue: _targetIdController.text.isEmpty
                            ? null
                            : _targetIdController.text,
                        decoration: const InputDecoration(
                          labelText: 'Target product',
                        ),
                        items: [
                          for (final product in _products)
                            DropdownMenuItem(
                              value: product.id,
                              child: Text(product.nameFor(AppLocale.instance.language)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _targetIdController.text = value);
                        },
                      ),
              if (_targetTypeController.text == 'category')
                _loadingTargets
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<String>(
                        initialValue: _targetIdController.text.isEmpty
                            ? null
                            : _targetIdController.text,
                        decoration: const InputDecoration(
                          labelText: 'Target category',
                        ),
                        items: [
                          for (final category in _categories)
                            DropdownMenuItem(
                              value: category.id,
                              child: Text(category.nameFor(AppLocale.instance.language)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _targetIdController.text = value);
                        },
                      ),
              const SizedBox(height: AppDimensions.md),
              TextField(
                controller: _targetUrlController,
                decoration: const InputDecoration(labelText: 'Target URL'),
              ),
              const SizedBox(height: AppDimensions.md),
              TextField(
                controller: _sortOrderController,
                decoration: const InputDecoration(labelText: 'Sort order'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: [
                  Text(S.published),
                  const SizedBox(width: AppDimensions.md),
                  Switch(
                    value: _isPublished,
                    onChanged: (value) => setState(() => _isPublished = value),
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
