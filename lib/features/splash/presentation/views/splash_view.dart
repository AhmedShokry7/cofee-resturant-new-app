import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/preview/preview_bridge.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/design/data/model/native_section.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_state.dart';
import 'package:new_coffee/features/splash/presentation/views/widgets/splash_brand_mark.dart';
import 'package:new_coffee/shared/widgets/design_page_sections.dart';

/// شاشة الافتتاحية: تعرض إعداداتها المنشورة ثم تسلّم للمسار الذي اختاره
/// التطبيق كما هو. غياب إعدادات منشورة يحافظ على شكل ومدة الشاشة الأصليين.
class SplashView extends StatefulWidget {
  const SplashView({super.key, required this.targetRoute});

  static const routeName = '/splash';

  /// المسار الحالي الذي يتابع إليه التطبيق بعد الافتتاحية.
  final String targetRoute;

  /// المدة الافتراضية للتوافق مع أي مستند قديم أو غائب.
  static const Duration displayDuration = Duration(milliseconds: 1000);

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  Timer? _timer;
  bool _hasNavigated = false;
  Duration? _scheduledDuration;
  final Stopwatch _visibleTime = Stopwatch();

  SplashSettings _settings(DesignState state) =>
      SplashSettings.fromSections(state.pageSections('splash'));

  @override
  void initState() {
    super.initState();
    if (PreviewBridge().isActive) return;
    _visibleTime.start();
    _scheduleInitialHandover(context.read<DesignCubit>());
  }

  Future<void> _scheduleInitialHandover(DesignCubit cubit) async {
    try {
      await cubit.initialLoad;
    } catch (_) {
      // If the first read fails, retain the documented one-second default.
    }
    if (!mounted || PreviewBridge().isActive) return;
    _scheduleHandover(_settings(cubit.state).duration);
  }

  void _scheduleHandover(Duration duration) {
    if (_hasNavigated || _scheduledDuration == duration) return;
    _timer?.cancel();
    _scheduledDuration = duration;
    final remaining = duration - _visibleTime.elapsed;
    _timer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      _openTargetRoute,
    );
  }

  void _openTargetRoute() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacementNamed(widget.targetRoute);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DesignCubit, DesignState>(
      listenWhen: (previous, next) => previous.design != next.design,
      listener: (context, state) {
        if (state.isLoaded && !PreviewBridge().isActive) {
          _scheduleHandover(_settings(state).duration);
        }
      },
      child: BlocBuilder<DesignCubit, DesignState>(
        buildWhen: (previous, next) => previous.design != next.design,
        builder: (context, state) {
          final settings = _settings(state);
          return Scaffold(
            backgroundColor: SplashSettings.colorFromHex(
              settings.backgroundColor,
              fallback: AppColor.background,
            ),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Align(
                      alignment: switch (settings.verticalAlignment) {
                        'top' => Alignment.topCenter,
                        'bottom' => Alignment.bottomCenter,
                        _ => Alignment.center,
                      },
                      child: DesignPageSectionsInline(
                        pageId: 'splash',
                        child: settings.visible
                            ? SplashBrandMark(settings: settings)
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
