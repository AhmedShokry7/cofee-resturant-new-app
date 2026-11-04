import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_palette.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// حقل بحث العميل داخل الهاتف: كبسولة رمادية بنفس مقاس كبسولة البحث في تطبيق
/// العميل، وهي حقل كتابة فعلي لا هدف ضغط.
///
/// النص الذي يُكتب يُرفع إلى الـ cubit في كل ضغطة، فتُصفّى قائمة المنتجات
/// بقاعدة التطبيق نفسه؛ الحقل يُطبع بقيمته من الحالة ولا يخزّن نصًا لنفسه.
class SimulatorSearchField extends StatefulWidget {
  const SimulatorSearchField({
    super.key,
    required this.value,
    required this.hintText,
    required this.onChanged,
  });

  final String value;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  State<SimulatorSearchField> createState() => _SimulatorSearchFieldState();
}

class _SimulatorSearchFieldState extends State<SimulatorSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant SimulatorSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text == widget.value) return;
    _controller.value = TextEditingValue(
      text: widget.value,
      selection: TextSelection.collapsed(offset: widget.value.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = SimulatorPalette.of(context);
    // الحقل يحتاج Material حوله، والمحاكي يُركّب في أشجار مختلفة (الهاتف هنا
    // وشاشة اختبار معزولة هناك)، فالطبقة تخصّ التحكم نفسه لا والِدَه.
    return Material(
      color: AppColor.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        style: AppFonts.regular14(context)
            .copyWith(color: palette.textPrimary ?? adminHeadingColor(theme)),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppFonts.regular14(context)
              .copyWith(color: palette.textSecondary ?? adminMutedColor(theme)),
          prefixIcon: AppIcon(
            AppIcons.search01,
            size: AppSizes.px20,
            color: palette.textSecondary ?? AppColor.greyColor,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: AppSizes.px40,
            minHeight: AppSizes.px40,
          ),
          filled: true,
          fillColor: adminTintedSurfaceColor(theme),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide(color: palette.primary),
          ),
        ),
      ),
    );
  }
}
