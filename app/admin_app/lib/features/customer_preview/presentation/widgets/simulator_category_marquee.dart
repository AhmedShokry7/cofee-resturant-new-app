import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_tokens.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// صف دوائر التصنيفات في أعلى صفحة العميل، يمشي وحده بلا توقف.
///
/// التصنيفات تتكرر في الصف فلا ينفد: كل اسم يمر أمام الموظف دون أن يلمس
/// الشاشة، وهو يظل يقدر يمرره بإصبعه أو بمفاتيحه — الحركة زينة، والاختيار هو
/// الفعل الذي يوصل شاشة التصنيف. السرعة بالأرقام نفسها التي يمشي بها تطبيق
/// العميل: قدر ثلاثة أرباع عرض الدائرة في الثانية.
class SimulatorCategoryMarquee extends StatefulWidget {
  const SimulatorCategoryMarquee({
    super.key,
    required this.categories,
    required this.language,
    required this.onSelect,
  });

  final List<AdminCategory> categories;
  final AppLanguage language;
  final ValueChanged<AdminCategory> onSelect;

  /// كم من الثانية يمشي الصف، بالأرخص المنطقية.
  static const double pixelsPerSecond = 16.0;

  /// مدة دورة كاملة لعدد من الدوائر: مسافة الدورة على السرعة.
  static Duration turnFor(int count) => Duration(
    microseconds:
        (count *
                SimulatorCategoryChip.slot /
                pixelsPerSecond *
                Duration.microsecondsPerSecond)
            .round(),
  );

  @override
  State<SimulatorCategoryMarquee> createState() =>
      _SimulatorCategoryMarqueeState();
}

class _SimulatorCategoryMarqueeState extends State<SimulatorCategoryMarquee>
    with SingleTickerProviderStateMixin {
  /// عرض التلاشي عند كل حافة من حواف الصف.
  static const double _edgeFade = AppSizes.px24;

  final ScrollController _scroll = ScrollController();
  late final AnimationController _walk = AnimationController(vsync: this)
    ..addListener(_followWalk);

  Timer? _resume;
  bool _held = false;
  bool _reduceMotion = false;

  /// المسافة التي تغطيها دورة واحدة: كل الدوائر مرة واحدة.
  double get _cycle => widget.categories.length * SimulatorCategoryChip.slot;

  /// دائرة واحدة لا صف يمشي، ومن طلب تقليل الحركة لا يُعطى حركة.
  bool get _walks => !_reduceMotion && widget.categories.length > 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncWalk();
  }

  @override
  void didUpdateWidget(covariant SimulatorCategoryMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categories.length != widget.categories.length) _syncWalk();
  }

  @override
  void dispose() {
    _resume?.cancel();
    _walk.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _syncWalk() {
    if (!_walks) {
      _resume?.cancel();
      _walk.stop();
      return;
    }
    _walk.duration = SimulatorCategoryMarquee.turnFor(widget.categories.length);
    if (!_held && !_walk.isAnimating) _walk.repeat();
  }

  void _followWalk() {
    if (!_scroll.hasClients || _cycle <= 0) return;
    _scroll.jumpTo(_cycle * _walk.value);
  }

  void _hold() {
    _held = true;
    _resume?.cancel();
    _walk.stop();
  }

  /// يستأنف من الدوائر التي على الشاشة لا من أول التصنيفات: الدورة تتكرر كل
  /// [_cycle] فبدايتها من موضعها الحالي لا تقطع الحركة.
  void _resumeWalk() {
    if (!mounted || !_walks) return;
    final offset = _scroll.hasClients ? _scroll.offset % _cycle : 0.0;
    _walk.value = offset / _cycle;
    _walk.repeat();
  }

  void _scheduleResume() {
    _held = false;
    _resume?.cancel();
    if (!_walks) return;
    _resume = Timer(SimulatorMotion.marqueeResume, _resumeWalk);
  }

  /// كم نسخة من القائمة يرصها الصف: نسختان على الأقل لأن الدورة تنتهي عند
  /// بداية الثانية، وزيادة تملأ الشاشة لحظة الالتفاف.
  int _copies(double viewportWidth) {
    if (widget.categories.length < 2) return 1;
    return math.max(2, (viewportWidth / _cycle).ceil() + 1);
  }

  /// نصيب كل حافة من التلاشي، فيبقى بعرض [_edgeFade] مهما اتسع الصف.
  double _fadeStop(double width) =>
      math.min(_edgeFade / math.max(width, 1.0), 0.4);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final copies = _copies(constraints.maxWidth);
        final stop = _fadeStop(constraints.maxWidth);
        return Listener(
          onPointerDown: (_) => _hold(),
          onPointerUp: (_) => _scheduleResume(),
          onPointerCancel: (_) => _scheduleResume(),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (Rect bounds) => LinearGradient(
              colors: const [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, stop, 1.0 - stop, 1.0],
            ).createShader(bounds),
            child: SizedBox(
              height: SimulatorCategoryChip.height(context),
              child: ListView.builder(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemExtent: SimulatorCategoryChip.slot,
                itemCount: widget.categories.length * copies,
                itemBuilder: (context, index) {
                  final category =
                      widget.categories[index % widget.categories.length];
                  return SimulatorCategoryChip(
                    category: category,
                    language: widget.language,
                    onTap: () => widget.onSelect(category),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// دائرة تصنيف واحدة: صورتها أو رمزها، واسمها تحتها.
///
/// البطاقة تملك أرقامها: الصف يرصّها بـ[slot] ويرتفع بقدر [height]، فتغيير
/// رقم هنا يمشي مع الصف لا خلفه.
class SimulatorCategoryChip extends StatelessWidget {
  const SimulatorCategoryChip({
    super.key,
    required this.category,
    required this.language,
    required this.onTap,
  });

  final AdminCategory category;
  final AppLanguage language;
  final VoidCallback onTap;

  static const double diameter = AppDimensions.simulatorCategoryTile;

  /// الهواء بين دائرتين: خطوة أقل من فصل البطاقات، فيبقى الصف عقدًا واحدًا.
  static const double gap = AppDimensions.simulatorCategoryChipGap;

  static const double slot = AppDimensions.simulatorCategoryChipSlot;

  /// سطر الاسم: يتبع مقاس حرف النظام، لأن سطرًا بثابت يقطع حروف من طلب
  /// خطًا كبيرًا.
  static double labelHeight(BuildContext context) {
    final size = AppFonts.medium12(context).fontSize ?? AppFontSizes.size12;
    return MediaQuery.textScalerOf(context).scale(size) *
        AppTextHeights.line1_5;
  }

  static double height(BuildContext context) =>
      diameter + gap + labelHeight(context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = category.nameFor(language);
    final image = category.imageUrl?.trim() ?? '';
    return Semantics(
      button: true,
      label: name,
      child: Material(
        color: AppColor.transparent,
        child: InkWell(
          onTap: onTap,
          // حبر بشكل ما يُضغط: مربع خلف دائرة يظهر عطلًا لحظة اللمس.
          customBorder: const CircleBorder(),
          child: Column(
            children: [
              Container(
                height: diameter,
                width: diameter,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: adminTintedSurfaceColor(theme),
                  border: Border.all(color: AppColor.primaryRing),
                  boxShadow: SimulatorShadows.tile,
                ),
                // الصورة حين تكون، وإلا الرمز من icon_key نفسه الذي يقرأه
                // العميل، فلا تبقى الدائرة فارغة أبدًا.
                child: image.isEmpty
                    ? Center(
                        child: AppIcon(
                          _iconOf(category.iconKey),
                          size: AppSizes.px26,
                          color: AppColor.primaryColor,
                        ),
                      )
                    : AdminNetworkThumb(
                        imageUrl: image,
                        width: diameter,
                        height: diameter,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        icon: _iconOf(category.iconKey),
                      ),
              ),
              const SizedBox(height: gap),
              SizedBox(
                width: slot,
                height: labelHeight(context),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.medium12(context)
                      .copyWith(color: adminBodyColor(theme)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// الرموز بأسمائها في تطبيق العميل: مفتاح واحد في القاعدة، رمز واحد هنا
  /// وواحد هناك، فلا يختلف الشكل بين المعاينة والجهاز.
  static IconData _iconOf(String? key) {
    return switch (key) {
      'hot_coffee' => AppIcons.coffee01,
      'cold_coffee' => AppIcons.bubbleTea01,
      'tea' => AppIcons.tea,
      'desserts' => AppIcons.iceCream01,
      'snacks' => AppIcons.cookie,
      'milkshakes' => AppIcons.milkBottle,
      'soft_drinks' => AppIcons.sodaCan,
      'bakery' => AppIcons.croissant,
      'donuts' => AppIcons.cupcake01,
      'bundles' => AppIcons.package02,
      _ => AppIcons.gridView,
    };
  }
}
