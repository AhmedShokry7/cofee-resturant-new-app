import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/product_subscriptions/data/repositories/product_subscription_repository.dart';
import '../manager/product_subscriptions_cubit.dart';
import '../manager/product_subscriptions_state.dart';
import 'product_subscription_form_page.dart';

class MyProductSubscriptionsPage extends StatelessWidget {
  const MyProductSubscriptionsPage({super.key});
  static const routeName = '/my-product-subscriptions';
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProductSubscriptionsCubit(ProductSubscriptionRepository())..load(),
      child: Scaffold(
        appBar: AppBar(title: Text(S.productSubscriptions)),
        floatingActionButton: Builder(builder: (context)=>FloatingActionButton(
          onPressed: () async { final changed = await Navigator.of(context).pushNamed(ProductSubscriptionFormPage.routeName); if(changed==true && context.mounted) context.read<ProductSubscriptionsCubit>().load(); },
          child: const Icon(Icons.add),
        )),
        body: BlocBuilder<ProductSubscriptionsCubit, ProductSubscriptionsState>(
          builder: (context, state){
            if(state.status==ProductSubscriptionsStatus.loading) return const Center(child:CircularProgressIndicator());
            if(state.status==ProductSubscriptionsStatus.failure) return Center(child:Text(state.error ?? 'Error'));
            if(state.items.isEmpty) return Center(child: Text(S.productSubscriptions));
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: state.items.length,
              separatorBuilder: (_,__)=>const SizedBox(height:8),
              itemBuilder: (context,i){
                final s = state.items[i];
                return Card(child: ListTile(
                  title: Text(s.name ?? s.frequency),
                  subtitle: Text('${s.status} • ${s.frequency} • next ${s.nextRunAt?.toLocal() ?? '-'}'),
                  trailing: Wrap(spacing:4, children:[
                    if(s.status=='active') TextButton(onPressed:()=>context.read<ProductSubscriptionsCubit>().pause(s.id), child: const Text('Pause')),
                    if(s.status=='paused') TextButton(onPressed:()=>context.read<ProductSubscriptionsCubit>().resume(s.id), child: const Text('Resume')),
                    if(s.status!='cancelled') TextButton(onPressed:()=>context.read<ProductSubscriptionsCubit>().cancel(s.id), child: const Text('Cancel')),
                  ]),
                ));
              },
            );
          },
        ),
      ),
    );
  }
}
