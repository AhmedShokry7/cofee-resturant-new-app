import 'package:admin_app/core/catalog/catalog_data.dart';
import 'package:admin_app/core/customers/customer_details_reader.dart';
import 'package:admin_app/core/delivery_zones/delivery_zone_repository.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/features/customers/data/repositories/admin_customer_repository.dart';
import 'package:admin_app/features/orders/data/repositories/admin_order_repository.dart';
import 'package:admin_app/features/orders/domain/repositories/order_repository.dart';
import 'package:admin_app/features/delivery_zones/data/repositories/admin_delivery_zone_repository.dart';

/// نقطة التركيب: تصل عقود البيانات بتنفيذاتها، فتستورد الشاشات العقد وحده
/// ولا يستورد فيتشرٌ فيتشرًا آخر.
///
/// النسخ تُبنى عند أول طلب فقط: كلٌّ منها بلا حالة، ومفتاح Supabase يُقرأ وقت
/// الاستدعاء، فتبقى الشاشة تختبر بما تشاء من بدائل تمررها في كونستركورها.
abstract final class AppDependencies {
  AppDependencies._();

  static CatalogData? _catalog;
  static DeliveryZoneRepository? _deliveryZones;
  static CustomerDetailsReader? _customerDetails;
  static OrderRepository? _orders;

  static CatalogData get catalog => _catalog ??= AdminProductRepository();

  static OrderRepository get orders => _orders ??= AdminOrderRepository();

  static CustomerDetailsReader get customerDetails =>
      _customerDetails ??= AdminCustomerRepository();

  static DeliveryZoneRepository get deliveryZones =>
      _deliveryZones ??= AdminDeliveryZoneRepository();
}
