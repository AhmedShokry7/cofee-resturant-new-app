import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// تسميات المحور الرأسي لمنحنى، على حافة اللوحة في جهة القراءة.
///
/// كل تسمية تُوسَّط على خطّ الشبكة المقابل لها بال [`Align`] بدل عمود
/// `spaceBetween`: عمودٌ مفرَّغ يضع أعلى رقم فوق الخط لا في وسطه، فتُقرأ
/// التسمية على صفّين لا على قيمتها. والتسميات تصل من الصفحة محسوبة، فاللوحة
/// لا تعرف عملات ولا مقاييس.
class AdminTrendValueAxis extends StatelessWidget {
  const AdminTrendValueAxis({
    super.key,
    required this.labels,
    required this.height,
    this.width = AppSizes.px48,
  }) : assert(labels.length >= 2);

  /// من أعلى المحور إلى أسفله، بالترتيب الذي يُطبع به.
  final List<String> labels;

  /// ارتفاع اللوحة التي تُوسَّط التسميات عليها.
  final double height;

  /// عرض العمود، حتى لا يزحف المحور على مساحة الرسم.
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = labels.length - 1;
    return SizedBox(
      height: height,
      width: width,
      child: Stack(
        children: [
          for (final (index, label) in labels.indexed)
            Positioned.fill(
              child: Align(
                alignment: Alignment(0, index * 2 / last - 1),
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size8,
                    height: AppTextHeights.line1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
