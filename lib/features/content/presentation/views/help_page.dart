import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/content/data/repositories/content_repository.dart';
import 'package:new_coffee/features/content/presentation/manager/faqs/faqs_cubit.dart';
import 'package:new_coffee/features/content/presentation/manager/faqs/faqs_state.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const routeName = "helpRoute";

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FaqsCubit(
        repository: context.read<ContentRepository>(),
      ),
      child: const _FaqsView(),
    );
  }
}

class _FaqsView extends StatelessWidget {
  const _FaqsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.help)),
      body: BlocBuilder<FaqsCubit, FaqsState>(
        builder: (context, state) {
          if (state.isLoading) return const FaqLoadingView();
          if (state.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(S.couldNotLoadFaqs, textAlign: TextAlign.center),
                  SizedBox(height: SpacingTokens.md.h),
                  TextButton(
                    onPressed: () => context.read<FaqsCubit>().load(),
                    child: Text(S.retry),
                  ),
                ],
              ),
            );
          }
          if (state.faqs.isEmpty) return Center(child: Text(S.noFaqs));
          return ListView(
            padding: EdgeInsets.fromLTRB(
              SpacingTokens.lg.w,
              SpacingTokens.md.h,
              SpacingTokens.lg.w,
              SpacingTokens.lg.w,
            ),
            children: [
              Text(S.faqTitle, style: AppFonts.semiBold16(context)),
              SizedBox(height: SpacingTokens.md.h),
              ...state.faqs.map(
                (faq) => Container(
                  margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColor.whiteColor,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColor.borderColor),
                  ),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    iconColor: AppColor.primaryColor,
                    collapsedIconColor: AppColor.greyColor,
                    title: Text(
                      faq.question,
                      style: AppFonts.medium16(context),
                    ),
                    childrenPadding: EdgeInsets.fromLTRB(
                      SpacingTokens.lg.w,
                      0,
                      SpacingTokens.lg.w,
                      SpacingTokens.lg.h,
                    ),
                    children: [
                      Text(
                        faq.answer,
                        style: AppFonts.regular14(context)
                            .copyWith(color: AppColor.greyColor, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
