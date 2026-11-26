import 'package:new_coffee/shared/widgets/custom_btn.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/customer_bundles/data/model/customer_bundle.dart';
import 'package:new_coffee/features/customer_bundles/data/repositories/customer_bundle_repository.dart';
import 'package:new_coffee/features/customer_bundles/presentation/views/my_bundles_page.dart';
import 'package:new_coffee/features/customer_bundles/presentation/views/customer_bundle_editor_page.dart';
import 'package:new_coffee/features/customer_bundles/presentation/views/bundle_product_image_strip.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_title.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/shared/widgets/animated_add_to_cart_button.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

/// Customer-created bundles are saved shopping lists, not subscription plans.
/// Their total is refreshed from the current branch catalogue before display.
class HomePersonalBundlesSection extends StatefulWidget {
  const HomePersonalBundlesSection({super.key});

  @override
  State<HomePersonalBundlesSection> createState() =>
      _HomePersonalBundlesSectionState();
}

class _HomePersonalBundlesSectionState
    extends State<HomePersonalBundlesSection> {
  StreamSubscription<dynamic>? _authSubscription;
  bool _adding = false;
  late final _bundleRepository = CustomerBundleRepository();

  @override
  void initState() {
    super.initState();
    if (SupabaseService.isReady) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((
        _,
      ) {
        if (mounted) context.read<HomeCubit>().loadPersonalBundles();
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() =>
      context.read<HomeCubit>().loadPersonalBundles(forceRefresh: true);

  Future<void> _addBundle(CustomerBundle bundle) async {
    if (_adding) return;
    final home = context.read<HomeCubit>();
    final products = home.state.personalBundleProducts;
    final missing = bundle.items.any(
      (item) => !products.containsKey(item.productId),
    );
    if (missing || bundle.items.isEmpty) {
      throw StateError(S.personalBundleProductsUnavailable);
    }
    setState(() => _adding = true);
    try {
      final cart = context.read<CartCubit>();
      final branchId = home.branchId;
      if (branchId != null && branchId.trim().isNotEmpty) {
        await cart.setBranch(branchId);
      }
      if (!mounted) return;
      final components = [
        for (final item in bundle.items)
          CartBundleComponent(
            productId: item.productId,
            quantity: item.quantity,
            unitPrice: products[item.productId]!.price,
          ),
      ];
      final firstProduct = products[bundle.items.first.productId]!;
      cart.addPersonalBundle(
        customerBundleId: bundle.id,
        title: bundle.name,
        image: firstProduct.displayImageUrl ?? firstProduct.image,
        price: totalFor(bundle, products),
        components: components,
      );
      unawaited(_bundleRepository.markUsed(bundle.id).catchError((_) {}));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.couldNotAddPersonalBundle)));
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  double totalFor(CustomerBundle bundle, Map<String, ProductModel> products) =>
      bundle.items.fold<double>(
        0,
        (total, item) =>
            total + (products[item.productId]?.price ?? 0) * item.quantity,
      );

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeCubit>();
    final state = home.state;
    final bundles = state.personalBundles;
    final products = state.personalBundleProducts;
    if (!SupabaseService.isSignedIn) return const SizedBox.shrink();
    // The first load is part of the home-page loading state. On later refreshes
    // keep this section's last result in place instead of showing its own spinner.
    if (state.isPersonalBundlesLoading && bundles.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(title: S.myBundles),
        const SizedBox(height: AppSpacing.sm),
        if (state.personalBundlesFailed)
          Card(
            child: ListTile(
              title: Text(S.couldNotLoadBundles),
              trailing: CustomIconButton(
                onPressed: _load,
                icon: const Icon(AppIcons.refresh),
                tooltip: S.retry,
              ),
            ),
          )
        else if (bundles.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(AppIcons.bundle),
              title: Text(S.createYourFirstPersonalBundle),
              subtitle: Text(S.personalBundlesAreSavedLists),
              trailing: const Icon(AppIcons.forward),
              onTap: () =>
                  Navigator.of(context)
                      .pushNamed(MyBundlesPage.routeName)
                      .then((_) => _load()),
            ),
          )
        else ...[
          Text(
            S.personalBundleCurrentPriceNote,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColor.greyColor),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: AppSizes.px240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: bundles.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) => _PersonalBundleCard(
                bundle: bundles[index],
                products: products,
                adding: _adding,
                onAdd: () => _addBundle(bundles[index]),
                onManage: () => _openBundle(bundles[index]),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openBundle(CustomerBundle bundle) async {
    await Navigator.of(context)
        .pushNamed(CustomerBundleEditorPage.routeName, arguments: bundle);
    if (mounted) await _load();
  }
}

class _PersonalBundleCard extends StatelessWidget {
  const _PersonalBundleCard({
    required this.bundle,
    required this.products,
    required this.adding,
    required this.onAdd,
    required this.onManage,
  });

  final CustomerBundle bundle;
  final Map<String, ProductModel> products;
  final bool adding;
  final Future<void> Function() onAdd;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final availableItems = bundle.items
        .where((item) => products.containsKey(item.productId))
        .toList(growable: false);
    final total = availableItems.fold<double>(
      0,
      (sum, item) => sum + products[item.productId]!.price * item.quantity,
    );
    return SizedBox(
      width: AppSizes.px224,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onManage,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(AppIcons.bundle),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        bundle.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                if ((bundle.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AppIconSize.xl + AppSpacing.sm,
                    ),
                    child: Text(
                      bundle.description!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColor.greyColor),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                BundleProductImageStrip(
                  items: bundle.items,
                  imageSize: 52,
                  maxImages: 2,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${bundle.items.length} ${S.bundleItems.toLowerCase()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Row(
                  children: [
                    if (availableItems.length == bundle.items.length)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${S.currentEstimate}: '),
                          PriceLabel(amount: total),
                        ],
                      )
                    else
                      Expanded(
                        child: Text(
                          S.personalBundleProductsUnavailable,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: AnimatedAddToCartButton(
                    onAdd: onAdd,
                    label: S.addBundleItemsToCart,
                    enabled:
                        !adding &&
                        bundle.items.isNotEmpty &&
                        availableItems.length == bundle.items.length,
                    onError: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
