import 'package:new_coffee/core/theme/app_color.dart';
import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/customer_bundles/data/model/customer_bundle.dart';
import 'package:new_coffee/features/customer_bundles/data/repositories/customer_bundle_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/supabase_product_repository.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';

class CustomerBundleEditorPage extends StatefulWidget {
  const CustomerBundleEditorPage({super.key});
  static const routeName = '/customer-bundle-editor';

  @override
  State<CustomerBundleEditorPage> createState() =>
      _CustomerBundleEditorPageState();
}

class _CustomerBundleEditorPageState extends State<CustomerBundleEditorPage> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final List<CustomerBundleItem> _items = <CustomerBundleItem>[];
  bool _saving = false;
  bool _loading = true;
  List<Map<String, dynamic>> _products = const [];
  String? _error;
  bool _initialized = false;

  CustomerBundle? _editing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is CustomerBundle) {
      _editing = args;
      _name.text = args.name;
      _desc.text = args.description ?? '';
      _items.addAll(args.items);
    }
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final c = SupabaseService.client;
      final rows = await c
          .from('products')
          .select('id,name_ar,name_en,base_price,image_url')
          .eq('is_active', true)
          .limit(1000);
      if (!mounted) return;
      setState(() {
        _products = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _addItemDialog() async {
    String? productId;
    int qty = 1;
    String query = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          scrollable: true,
          title: DesignText(S.addItem, page: 'customer_bundle_editor', label: 'addItem'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  labelText: S.search,
                  hintText: S.product,
                  prefixIcon: const Icon(AppIcons.search),
                ),
                onChanged: (value) => setDialog(() => query = value.trim()),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (productId == null)
                SizedBox(
                  width: double.maxFinite,
                  height:
                      (MediaQuery.sizeOf(ctx).height -
                              MediaQuery.viewInsetsOf(ctx).bottom -
                              320)
                          .clamp(120.0, 460.0),
                  child: Builder(
                    builder: (context) {
                      final normalized = query.toLowerCase();
                      final matches = _products
                          .where((product) {
                            final name =
                                '${product['name_ar'] ?? ''} ${product['name_en'] ?? ''}'
                                    .toLowerCase();
                            return normalized.isEmpty ||
                                name.contains(normalized);
                          })
                          .toList(growable: false);
                      if (matches.isEmpty) {
                        return Center(child: DesignText(S.noProductsFound, page: 'customer_bundle_editor', label: 'noProductsFound'));
                      }
                      return ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final product = matches[index];
                          return ListTile(
                            dense: true,
                            leading: _productThumbnail(
                              product['image_url'] as String?,
                            ),
                            title: Text(
                              (product['name_ar'] ?? product['name_en'] ?? '')
                                  .toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: PriceLabel(
                              amount:
                                  (product['base_price'] as num?)?.toDouble() ??
                                  0,
                            ),
                            onTap: () => setDialog(
                              () => productId = product['id'] as String,
                            ),
                          );
                        },
                      );
                    },
                  ),
                )
              else
                Builder(
                  builder: (context) {
                    final product = _products.firstWhere(
                      (item) => item['id'] == productId,
                    );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _productThumbnail(
                        product['image_url'] as String?,
                      ),
                      title: Text(
                        (product['name_ar'] ?? product['name_en'] ?? '')
                            .toString(),
                      ),
                      subtitle: PriceLabel(
                        amount:
                            (product['base_price'] as num?)?.toDouble() ?? 0,
                      ),
                      trailing: CustomIconButton(
                        tooltip: S.edit,
                        icon: const Icon(AppIcons.edit),
                        onPressed: () => setDialog(() => productId = null),
                      ),
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int>(
                initialValue: qty,
                decoration: InputDecoration(labelText: S.quantity),
                items: List.generate(99, (i) => i + 1)
                    .map(
                      (q) => DropdownMenuItem<int>(value: q, child: Text('$q')),
                    )
                    .toList(),
                onChanged: (v) => setDialog(() => qty = v ?? 1),
              ),
            ],
          ),
          actions: [
            CustomTextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: DesignText(S.cancel, page: 'customer_bundle_editor', label: 'cancel'),
            ),
            CustomBtn(
              text: S.addItem,
              enabled: productId != null,
              onPressed: () {
                if (productId == null) return;
                final p = _products.firstWhere((e) => e['id'] == productId);
                setState(() {
                  final existingIndex = _items.indexWhere(
                    (item) => item.productId == productId,
                  );
                  if (existingIndex >= 0) {
                    final current = _items[existingIndex];
                    _items[existingIndex] = CustomerBundleItem(
                      id: current.id,
                      bundleId: current.bundleId,
                      productId: current.productId,
                      quantity: (current.quantity + qty).clamp(1, 99).toInt(),
                      productNameAr: current.productNameAr,
                      productNameEn: current.productNameEn,
                      productImageUrl: current.productImageUrl,
                      unitPrice: current.unitPrice,
                      selectedOptions: current.selectedOptions,
                      note: current.note,
                    );
                  } else {
                    _items.add(
                      CustomerBundleItem(
                        id: '',
                        bundleId: '',
                        productId: productId!,
                        quantity: qty,
                        productNameAr: p['name_ar'] as String?,
                        productNameEn: p['name_en'] as String?,
                        productImageUrl: p['image_url'] as String?,
                        unitPrice: (p['base_price'] as num?)?.toDouble(),
                      ),
                    );
                  }
                });
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _productThumbnail(String? imageUrl) {
    final url = imageUrl?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: SizedBox.square(
        dimension: 44,
        child: url.isEmpty
            ? const ColoredBox(
                color: AppColor.subtleOverlay,
                child: Icon(AppIcons.coffee),
              )
            : DbImage(image: url, fit: BoxFit.cover),
      ),
    );
  }

  Future<void> _openProduct(String productId) async {
    try {
      final products = await SupabaseProductRepository().getByIds([productId]);
      if (!mounted) return;
      if (products.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: DesignText(S.productUnavailable, page: 'customer_bundle_editor', label: 'productUnavailable')));
        return;
      }
      await Navigator.of(context)
          .pushNamed(ProductDetailsPage.routeName, arguments: products.first);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: DesignText(S.couldNotLoadProduct, page: 'customer_bundle_editor', label: 'couldNotLoadProduct')));
    }
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: DesignText(S.addAtLeastOneBundleProduct, page: 'customer_bundle_editor', label: 'addAtLeastOneBundleProduct')));
      return;
    }
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final repo = CustomerBundleRepository();
    try {
      if (_editing == null) {
        await repo.createBundle(
          name: name,
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          isFavorite: false,
          items: _items,
        );
      } else {
        await repo.updateBundle(
          id: _editing!.id,
          name: name,
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          isFavorite: _editing!.isFavorite,
          items: _items,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: DesignText(S.bundleSaved, page: 'customer_bundle_editor', label: 'bundleSaved')));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: DesignText(S.couldNotSaveBundle, page: 'customer_bundle_editor', label: 'couldNotSaveBundle')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: DesignText(
            _editing == null ? S.createBundle : S.edit,
            page: 'customer_bundle_editor',
            label: _editing == null ? 'title' : 'editTitle',
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: AppLayout.pageBody,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DesignText(S.couldNotLoadBundles, page: 'customer_bundle_editor', label: 'couldNotLoadBundles'),
                      const SizedBox(height: AppSpacing.md),
                      CustomBtn(
                        text: S.retry,
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _loadProducts();
                        },
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: AppLayout.pageBody,
                children: [
                  TextField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: S.bundleName),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _desc,
                    decoration: InputDecoration(labelText: S.bundleDescription),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DesignText(S.personalBundlesAreSavedLists, page: 'customer_bundle_editor', label: 'personalBundlesAreSavedLists'),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            S.personalBundleEditorPriceNote,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          S.bundleItems,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      CustomTextButton.icon(
                        onPressed: _addItemDialog,
                        icon: const Icon(AppIcons.add),
                        label: DesignText(S.addItem, page: 'customer_bundle_editor', label: 'addItem'),
                      ),
                    ],
                  ),
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: Center(child: DesignText(S.noBundleItems, page: 'customer_bundle_editor', label: 'noBundleItems')),
                    ),
                  ..._items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final it = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: _productThumbnail(it.productImageUrl),
                        title: Text(
                          it.productNameAr ?? it.productNameEn ?? it.productId,
                        ),
                        subtitle: Row(
                          children: [
                            Text('${S.quantity}: ${it.quantity}'),
                            if (it.unitPrice != null) ...[
                              const SizedBox(width: AppSpacing.sm),
                              PriceLabel(amount: it.unitPrice! * it.quantity),
                            ],
                          ],
                        ),
                        trailing: CustomIconButton(
                          icon: const Icon(AppIcons.delete),
                          tooltip: S.delete,
                          onPressed: () => setState(() => _items.removeAt(i)),
                        ),
                        onTap: () => _openProduct(it.productId),
                      ),
                    );
                  }),
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${S.currentEstimate}: '),
                          PriceLabel(
                            amount: _items.fold<double>(
                              0,
                              (total, item) =>
                                  total + (item.unitPrice ?? 0) * item.quantity,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  CustomBtn(
                    text: S.save,
                    onPressed: _submit,
                    isLoading: _saving,
                    enabled: !_saving,
                    width: double.infinity,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
      ),
    );
  }
}
