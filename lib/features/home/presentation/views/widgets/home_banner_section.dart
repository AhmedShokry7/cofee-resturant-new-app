import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/presentation/manager/banner/banner_cubit.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/banner_details_page.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/banner_dots.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/banner_image.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/motion_tokens.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class HomeBannerSection extends StatelessWidget {
  const HomeBannerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final banners = context.watch<HomeCubit>().state.banners;
    if (banners.isEmpty) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => BannerCubit(length: banners.length),
      child: _BannerCarousel(banners: banners),
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners});

  final List<BannerModel> banners;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _controller = PageController();

  /// How long one auto-advance takes.
  ///
  /// This is the perceived "transition time" of the carousel, so it is kept
  /// short: past roughly a third of a second the slide starts to feel like a
  /// wait rather than a cut. The curve arrives quickly and settles, which reads
  /// as noticeably snappier at the same duration.
  static const _transition = MotionTokens.pageSlide;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BannerCubit, BannerState>(
      listenWhen: (previous, current) => previous.index != current.index,
      listener: (context, state) {
        if (!_controller.hasClients) return;
        if (_controller.page?.round() == state.index) return;
        _controller.animateToPage(
          state.index,
          duration: _transition,
          curve: MotionTokens.entranceCurve,
        );
      },
      child: Column(
        children: [
          SizedBox(
            height: AppDimensions.homeBannerHeight,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.banners.length,
              onPageChanged: (index) =>
                  context.read<BannerCubit>().jumpTo(index),
              itemBuilder: (context, index) {
                final banner = widget.banners[index];
                return Semantics(
                  link: true,
                  label: banner.title,
                  child: Material(
                    color: AppColor.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pushNamed(
                        BannerDetailsPage.routeName,
                        arguments: banner,
                      ),
                      child: BannerImage(
                        banner: banner,
                        borderRadius: AppRadius.none,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: AppSpacing.md),
          BlocBuilder<BannerCubit, BannerState>(
            builder: (context, state) =>
                BannerDots(count: widget.banners.length, current: state.index),
          ),
        ],
      ),
    );
  }
}
