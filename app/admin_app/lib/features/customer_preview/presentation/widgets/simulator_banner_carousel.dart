import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_tokens.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// بانرات العميل كما تظهر أعلى صفحته الرئيسية: شريط عريض بملء العرض يقلب
/// نفسه كل خمس ثوانٍ، وتحته نقطة لكل بنر.
///
/// الشريط يترك اللوحة بلا حافة جانبية لأن البنر عند العميل كامل العرض، فالهامش
/// هنا لا يأتي من المقطع حوله. رقم الصفحة حالة موضع في شريط لا حالة في التطبيق:
/// يبقى داخل هذا الملف لأن إعادة القراءة لا تعلّق عليه ولا اللوحة تقرأه.
class SimulatorBannerCarousel extends StatefulWidget {
  const SimulatorBannerCarousel({
    super.key,
    required this.banners,
    this.autoplay = true,
    this.radius = AppRadius.none,
  });

  final List<AdminBanner> banners;

  /// التقليب التلقائي قرار المحرّر على المقطع، فوق قرار صاحب الجهاز تقليل الحركة.
  final bool autoplay;

  /// زاوية البنر من شبكة الانحناء، وافتراضيتها قائمة كما عند الزبون.
  final double radius;

  @override
  State<SimulatorBannerCarousel> createState() =>
      _SimulatorBannerCarouselState();
}

class _SimulatorBannerCarouselState extends State<SimulatorBannerCarousel> {
  final PageController _controller = PageController();
  int _page = 0;
  Timer? _hold;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncHold();
  }

  @override
  void didUpdateWidget(covariant SimulatorBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length ||
        oldWidget.autoplay != widget.autoplay) {
      _syncHold();
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// هل يمشي الشريط وحده: قرار المحرّر على المقطع، وقرار صاحب الجهاز تقليل
  /// الحركة — فمن طلبها يرى شريطًا يقلبه بإصبعه بلا مؤقت.
  bool _shouldWalk() => widget.autoplay && !MediaQuery.disableAnimationsOf(context);

  /// يضبط المؤقت على عدد البنرات الموجود فعلًا: بنر واحد لا يقلب نفسه،
  /// وثلاثة تحتاج مؤقتًا يعمل.
  void _syncHold() {
    _hold?.cancel();
    if (!_shouldWalk() || widget.banners.length < 2) return;
    _hold = Timer.periodic(SimulatorMotion.carouselHold, (_) => _advance());
  }

  void _advance() {
    if (!mounted || !_controller.hasClients) return;
    final count = widget.banners.length;
    if (count < 2) return;
    final next = (_page + 1) % count;
    _controller.animateToPage(
      next,
      duration: SimulatorMotion.pageSlide,
      curve: SimulatorMotion.entranceCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.banners.length;
    return Column(
      children: [
        SizedBox(
          height: AppDimensions.simulatorBannerHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: count,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              // القياس من القيود لا من اللانهاية: صورة البنر تأخذ قدر الصفحة
              // كلها، والأيقونة البديلة تُحسب من رقم متمدّد.
              return LayoutBuilder(
                builder: (context, constraints) => AdminNetworkThumb(
                  imageUrl: banner.imageUrl,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  fit: BoxFit.fill,
                  borderRadius: BorderRadius.circular(widget.radius),
                  icon: AppIcons.image01,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < count; index++)
              AnimatedContainer(
                duration: SimulatorMotion.dotMorph,
                curve: SimulatorMotion.entranceCurve,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                height: index == _page ? AppSizes.px10 : AppSizes.px8,
                width: index == _page ? AppSizes.px10 : AppSizes.px8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _page
                      ? AppColor.primaryColor
                      : adminCardBorderColor(theme),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
