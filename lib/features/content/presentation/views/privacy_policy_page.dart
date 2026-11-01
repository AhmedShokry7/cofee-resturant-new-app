import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/content/data/repositories/content_repository.dart';
import 'package:new_coffee/features/content/presentation/manager/legal_document/legal_document_cubit.dart';
import 'package:new_coffee/features/content/presentation/manager/legal_document/legal_document_state.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const routeName = "privacyPolicyRoute";

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LegalDocumentCubit(
        repository: context.read<ContentRepository>(),
        slug: 'privacy',
      ),
      child: const _LegalDocumentView(),
    );
  }
}

class _LegalDocumentView extends StatelessWidget {
  const _LegalDocumentView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.privacyPolicy)),
      body: BlocBuilder<LegalDocumentCubit, LegalDocumentState>(
        builder: (context, state) {
          if (state.isLoading) return const PolicyLoadingView();
          if (state.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(S.couldNotLoadPolicy, textAlign: TextAlign.center),
                  SizedBox(height: SpacingTokens.md.h),
                  TextButton(
                    onPressed: () => context.read<LegalDocumentCubit>().load(),
                    child: Text(S.retry),
                  ),
                ],
              ),
            );
          }
          final text = state.document?.content ?? S.policyUnavailable;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              SpacingTokens.lg.w,
              SpacingTokens.md.h,
              SpacingTokens.lg.w,
              SpacingTokens.lg.w,
            ),
            child: Text(
              text,
              style: AppFonts.regular14(context)
                  .copyWith(color: AppColor.secondryColor, height: 1.6),
            ),
          );
        },
      ),
    );
  }
}
