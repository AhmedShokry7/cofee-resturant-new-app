import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing.dart';
import 'package:new_coffee/features/customer_bundles/data/repositories/customer_bundle_repository.dart';
import 'package:new_coffee/features/customer_bundles/presentation/manager/customer_bundles_cubit.dart';
import 'package:new_coffee/features/customer_bundles/presentation/manager/customer_bundles_state.dart';
import 'package:new_coffee/features/customer_bundles/presentation/views/customer_bundle_editor_page.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';

class MyBundlesPage extends StatelessWidget {
  const MyBundlesPage({super.key});
  static const routeName = '/my-bundles';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CustomerBundlesCubit(CustomerBundleRepository())..load(),
      child: Scaffold(
        appBar: AppBar(title: Text(S.myBundles)),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
            onPressed: () async {
              final changed = await Navigator.of(context).pushNamed(CustomerBundleEditorPage.routeName);
              if (changed == true && context.mounted) context.read<CustomerBundlesCubit>().load();
            },
            child: const Icon(Icons.add),
          ),
        ),
        body: BlocBuilder<CustomerBundlesCubit, CustomerBundlesState>(
          builder: (context, state) {
            if (state.status == CustomerBundlesStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == CustomerBundlesStatus.failure) {
              return Center(child: Text(state.error ?? 'Error'));
            }
            if (state.bundles.isEmpty) {
              return Center(child: DesignText(S.myBundles, page: 'my_bundles', label: 'empty'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: state.bundles.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final b = state.bundles[i];
                return Card(
                  child: ListTile(
                    title: Text(b.name),
                    subtitle: Text(b.description ?? '${b.items.length} items'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        final cubit = context.read<CustomerBundlesCubit>();
                        if (v == 'edit') {
                          final changed = await Navigator.of(context).pushNamed(
                            CustomerBundleEditorPage.routeName,
                            arguments: b,
                          );
                          if (changed == true && context.mounted) cubit.load();
                        } else if (v == 'dup') {
                          cubit.duplicate(b.id);
                        } else if (v == 'fav') {
                          cubit.toggleFavorite(b);
                        } else if (v == 'del') {
                          cubit.delete(b.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'dup', child: Text('Duplicate')),
                        PopupMenuItem(value: 'fav', child: Text('Favorite')),
                        PopupMenuItem(value: 'del', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
