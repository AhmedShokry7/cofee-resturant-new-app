import 'package:new_coffee/features/product_subscriptions/data/model/product_subscription.dart';
enum ProductSubscriptionsStatus { initial, loading, loaded, failure }
class ProductSubscriptionsState {
  const ProductSubscriptionsState({this.status=ProductSubscriptionsStatus.initial,this.items=const [],this.error});
  final ProductSubscriptionsStatus status;
  final List<ProductSubscription> items;
  final String? error;
  ProductSubscriptionsState copyWith({ProductSubscriptionsStatus? status,List<ProductSubscription>? items,String? error})=>ProductSubscriptionsState(status:status??this.status,items:items??this.items,error:error);
}
