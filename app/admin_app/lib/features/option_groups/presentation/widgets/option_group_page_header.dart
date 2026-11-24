import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/shared/widgets/admin_create_button.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';

class OptionGroupPageHeader extends StatelessWidget {
  const OptionGroupPageHeader({super.key, this.onAdd});

  /// 020 و225 يطلبان `catalog.product.write` لكتابة مجموعة، فالصفحة تُعرض
  /// للقارئ وزرّ الإضافة يُحجب عنه.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return AdminPageHeader(
      title: S.addonsPageTitle,
      subtitle: S.addonsPageDescription,
      actions: [
        if (onAdd != null)
          AdminCreateButton(label: S.addAddonGroup, onPressed: onAdd),
      ],
    );
  }
}
