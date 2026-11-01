import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/content/presentation/manager/faqs/faqs_cubit.dart';
import 'package:new_coffee/features/content/presentation/views/widgets/content_page_shell.dart';
import 'package:new_coffee/features/content/presentation/views/widgets/faqs_list.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

/// The help centre: the published questions, or why they could not be read.
class FaqsView extends StatelessWidget {
  const FaqsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FaqsCubit, FaqsState>(
      builder: (context, state) {
        return ContentPageShell(
          title: S.help,
          isLoading: state.isLoading,
          loadingView: const FaqLoadingView(),
          failureMessage: state.hasError ? S.couldNotLoadFaqs : null,
          onRetry: () => context.read<FaqsCubit>().load(),
          contentBuilder: (
            context,
          ) => state.faqs.isEmpty
              ? Center(child: Text(S.noFaqs))
              : FaqsList(faqs: state.faqs),
        );
      },
    );
  }
}
