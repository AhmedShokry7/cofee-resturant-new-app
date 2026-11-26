import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/customer_bundles/data/repositories/customer_bundle_repository.dart';
import 'package:new_coffee/features/customer_bundles/presentation/manager/customer_bundles_cubit.dart';
import 'package:new_coffee/features/customer_bundles/presentation/manager/customer_bundles_state.dart';
import 'package:new_coffee/features/customer_bundles/presentation/views/customer_bundle_editor_page.dart';
import 'package:new_coffee/features/customer_bundles/presentation/views/bundle_product_image_strip.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';

class MyBundlesPage extends StatelessWidget {
  const MyBundlesPage({super.key});
  static const routeName = '/my-bundles';

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: BlocProvider(
        create: (_) => CustomerBundlesCubit(CustomerBundleRepository())..load(),
        child: const _MyBundlesView(),
      ),
    );
  }
}

class _MyBundlesView extends StatelessWidget {
  const _MyBundlesView();

  Future<void> _openEditor(BuildContext context, {Object? arguments}) async {
    await Navigator.of(context)
        .pushNamed(CustomerBundleEditorPage.routeName, arguments: arguments);
    if (context.mounted) context.read<CustomerBundlesCubit>().load();
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.deleteBundleConfirm),
        actions: [
          CustomTextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.cancel),
          ),
          CustomTextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              S.delete,
              style: const TextStyle(color: AppColor.errorColor),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<CustomerBundlesCubit>().delete(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: DesignText(S.myBundles, page: 'my_bundles', label: 'myBundles'),
      ),
      body: BlocConsumer<CustomerBundlesCubit, CustomerBundlesState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        builder: (context, state) {
          if (state.status == CustomerBundlesStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == CustomerBundlesStatus.failure) {
            return EmptyState(
              icon: AppIcons.bundle,
              title: S.couldNotLoadBundles,
              actionLabel: S.retry,
              onAction: () => context.read<CustomerBundlesCubit>().load(),
            );
          }
          if (state.bundles.isEmpty) {
            return EmptyState(
              icon: AppIcons.bundle,
              title: S.noBundlesYet,
              subtitle: S.bundlesHint,
              actionLabel: S.createBundle,
              onAction: () => _openEditor(context),
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<CustomerBundlesCubit>().load(),
            child: ListView.separated(
              padding: AppLayout.pageBody,
              itemCount: state.bundles.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(AppIcons.information),
                      title: Text(S.personalBundlesAreSavedLists),
                      subtitle: Text(S.personalBundleCurrentPriceNote),
                    ),
                  );
                }
                final b = state.bundles[i - 1];
                return Card(
                  child: ListTile(
                    leading: SizedBox(
                      width: AppSizes.px48,
                      child: b.items.isEmpty
                          ? Icon(
                              b.isFavorite
                                  ? AppIcons.favourite
                                  : AppIcons.bundle,
                              color: b.isFavorite ? AppColor.errorColor : null,
                            )
                          : BundleProductImageStrip(
                              items: b.items,
                              imageSize: 48,
                              maxImages: 1,
                              showMoreCount: false,
                            ),
                    ),
                    title: Text(
                      b.name.trim().isNotEmpty ? b.name : S.createBundle,
                    ),
                    subtitle: Text(
                      '${b.items.length} ${S.bundleItems.toLowerCase()}',
                    ),
                    onTap: () => _openEditor(context, arguments: b),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') {
                          _openEditor(context, arguments: b);
                        } else if (v == 'dup') {
                          context.read<CustomerBundlesCubit>().duplicate(b.id);
                        } else if (v == 'fav') {
                          context.read<CustomerBundlesCubit>().toggleFavorite(
                            b,
                          );
                        } else if (v == 'del') {
                          _confirmDelete(context, b.id);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text(S.edit)),
                        PopupMenuItem(value: 'dup', child: Text(S.duplicate)),
                        PopupMenuItem(
                          value: 'fav',
                          child: Text(b.isFavorite ? S.unfavorite : S.favorite),
                        ),
                        PopupMenuItem(
                          value: 'del',
                          child: Text(
                            S.delete,
                            style: const TextStyle(color: AppColor.errorColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        child: const Icon(AppIcons.add),
      ),
    );
  }
}
