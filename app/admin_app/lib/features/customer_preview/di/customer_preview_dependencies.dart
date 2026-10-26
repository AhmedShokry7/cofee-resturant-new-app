import 'package:admin_app/features/customer_preview/data/emulator_bridge_client.dart';
import 'package:admin_app/features/customer_preview/domain/repositories/emulator_bridge.dart';

/// نقطة تركيب اعتمادات فيتشر معاينة تطبيق الزبون داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data` مباشرة.
abstract final class CustomerPreviewDependencies {
  CustomerPreviewDependencies._();

  /// جسر جديد لكل شاشة: الشاشة تُغلق عميل الشبكة في `dispose`، فلا يجوز
  /// مشاركة نسخة واحدة بين أكثر من معاينة.
  static EmulatorBridge newEmulatorBridge() => EmulatorBridgeClient();
}
