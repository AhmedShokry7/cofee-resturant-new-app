import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';

/// بانر العرض المنفرد الذي يوضع بين شريط المنتجات وشريط الترشيحات.
///
/// يأخذ نفس ارتفاع شريط البنرات لكن بزاية، ولا يُعرض إلا حين يكون هناك بنر
/// ثانٍ: تطبيق العميل يعرض البنر الثاني لا الأول، لأن الأول ظهر فوقه بالفعل.
class SimulatorPromoBanner extends StatelessWidget {
  const SimulatorPromoBanner({
    super.key,
    required this.banner,
    this.radius = AppRadius.md,
  });

  final AdminBanner banner;

  /// زاوية البانر من شبكة الانحناء، وافتراضيتها ما يرسمه المقطع اليوم.
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.simulatorBannerHeight,
      child: LayoutBuilder(
        builder: (context, constraints) => AdminNetworkThumb(
          imageUrl: banner.imageUrl,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          fit: BoxFit.fill,
          borderRadius: BorderRadius.circular(radius),
          icon: AppIcons.image01,
        ),
      ),
    );
  }
}
