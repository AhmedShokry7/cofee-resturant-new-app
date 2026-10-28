import 'package:admin_app/core/locale/app_strings.dart';

/// أنواع الاستلام التي تسمح بها `ck_orders_fulfillment_type` في القاعدة.
/// كل طلبات نقطة البيع `dine_in`، فغياب أي نوع هنا يجعله «نوع طلب غير معروف».
const kFulfillmentCodes = <String>['delivery', 'pickup', 'dine_in'];

/// تسمية نوع الاستلام، واحدة لكل الشاشات التي تعرض طلبًا.
///
/// كانت كل فيتشر تملك تبديلها الخاص، فيختلف نص «استلام» بين بطاقة العميل
/// وشاشة الطلب، وتطبع بطاقة العميل الرمز الخام `dine_in` لأنها نسيت نوع الفرع.
/// القراءة من القاعدة تبقى داخل الـ repositories، وهذه التسمية عرضٌ خالص.
String fulfillmentLabel(String code) => switch (code) {
  'delivery' => S.fulfillmentDelivery,
  'pickup' => S.fulfillmentPickup,
  'dine_in' => S.fulfillmentDineIn,
  _ => S.unknownFulfillment,
};
