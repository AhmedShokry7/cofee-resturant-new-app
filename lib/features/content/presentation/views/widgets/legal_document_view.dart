import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/layout_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/content/presentation/manager/legal_document/legal_document_cubit.dart';
import 'package:new_coffee/features/content/presentation/views/widgets/content_page_shell.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

/// A published legal document read as one column of plain text.
class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({super.key});

  /// Leading for a wall of prose the customer scans rather than reads closely.
  static const double bodyLineHeight = 1.6;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LegalDocumentCubit, LegalDocumentState>(
      builder: (context, state) {
        return ContentPageShell(
          title: S.privacyPolicy,
          isLoading: state.isLoading,
          loadingView: const PolicyLoadingView(),
          failureMessage: state.hasError ? S.couldNotLoadPolicy : null,
          onRetry: () => context.read<LegalDocumentCubit>().load(),
          contentBuilder: (context) => SingleChildScrollView(
            padding: LayoutTokens.pageBody(),
            child: Text(
              state.document?.content ?? S.policyUnavailable,
              style: AppFonts.regular14(
                context,
              ).copyWith(color: AppColor.secondryColor, height: bodyLineHeight),
            ),
          ),
        );
      },
    );
  }
}
