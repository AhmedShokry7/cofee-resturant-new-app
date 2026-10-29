import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// رمز دعوة بحروف لاتينية ثابتة العرض مع زر نسخه.
///
/// الرمز يُرسل إلى المدعو كما هو، فلا يُعرض داخل نص عربي مخلوط ولا يُقرأ من
/// القائمة مرة ثانية: القاعدة تعطيه كاتب الدعوة وحده.
class StaffCodeBlock extends StatelessWidget {
  const StaffCodeBlock({super.key, required this.code});

  final String code;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(S.staffInviteCodeCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSizes.px10,
        AppSizes.px8,
        AppSizes.px4,
        AppSizes.px8,
      ),
      decoration: BoxDecoration(
        color: dark ? AppColor.darkBackground : AppColor.adminTableHeader,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.adminTableBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                code,
                style: TextStyle(
                  color: dark ? AppColor.darkText : AppColor.adminBody,
                  fontSize: AppFontSizes.size10,
                  height: AppTextHeights.line1_6,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.px4),
          IconButton(
            tooltip: S.staffInviteCodeCopy,
            onPressed: () => _copy(context),
            style: IconButton.styleFrom(
              fixedSize: const Size(AppSizes.px30, AppSizes.px30),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: AppIcon(
              AppIcons.copy01,
              size: 16,
              color: adminMutedColor(theme),
            ),
          ),
        ],
      ),
    );
  }
}
