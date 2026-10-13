import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/features/home/data/banners_list.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/presentation/manager/banner/banner_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/banner_dots.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/banner_image.dart';

class HomeBannerSection extends StatelessWidget {
  const HomeBannerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final banners = getBannersList();
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
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
      child: Column(
        children: [
          SizedBox(
            height: 164.h,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.banners.length,
              onPageChanged: (index) =>
                  context.read<BannerCubit>().jumpTo(index),
              itemBuilder: (context, index) =>
                  BannerImage(banner: widget.banners[index]),
            ),
          ),
          SizedBox(height: SpacingTokens.md.h),
          BlocBuilder<BannerCubit, BannerState>(
            builder: (context, state) => BannerDots(
              count: widget.banners.length,
              current: state.index,
            ),
          ),
        ],
      ),
    );
  }
}
