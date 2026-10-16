import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/on_boarding/data/model/on_boarding_model.dart';
import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OnBoardingPageViewData extends StatelessWidget {
  const OnBoardingPageViewData({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnBoardingCubit, OnBoardingState>(
      builder: (context, state) {
        if (state is OnBoardingInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is OnBoardingError) {
          return Center(child: Text(state.message));
        }
        final List<OnBoardingModel> slides = switch (state) {
          OnBoardingLoaded(slides: final s) => s,
          OnBoardingPageChanged(slides: final s) => s,
          _ => const [],
        };
        if (slides.isEmpty) {
          return Center(child: Text(S.noSlides));
        }
        final cubit = context.read<OnBoardingCubit>();
        return PageView.builder(
          controller: cubit.pageController,
          onPageChanged: (value) => cubit.changePage(value),
          itemCount: slides.length,
          itemBuilder: (context, index) {
            final item = slides[index];
            return Column(
              children: [
                Expanded(
                  child: DbImage(image: item.image, fit: BoxFit.fill),
                ),
                SizedBox(height: 32.h),
                Text(
                  textAlign: TextAlign.center,
                  item.title,
                  style: AppFonts.semiBold24(context)
                      .copyWith(color: AppColor.primaryColor),
                ),
                const SizedBox(height: 12),
                Text(
                  textAlign: TextAlign.center,
                  item.body,
                  style: AppFonts.semiBold16(context)
                      .copyWith(color: AppColor.greyColor),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
