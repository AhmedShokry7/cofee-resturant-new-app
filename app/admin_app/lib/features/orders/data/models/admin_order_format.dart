import 'package:admin_app/core/locale/app_locale.dart';

import 'admin_order_record.dart';

extension AdminOrderFormat on AdminOrder {
  String branchNameFor(AppLanguage language) => language.isArabic
      ? branchNameAr?.trim() ?? ''
      : branchNameEn?.trim() ?? '';
}
