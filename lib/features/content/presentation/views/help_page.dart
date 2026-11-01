import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/content/data/repositories/content_repository.dart';
import 'package:new_coffee/features/content/presentation/manager/faqs/faqs_cubit.dart';
import 'package:new_coffee/features/content/presentation/views/widgets/faqs_view.dart';

/// The entry point of the help centre: it owns the cubit and nothing else.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const routeName = "helpRoute";

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          FaqsCubit(repository: context.read<ContentRepository>()),
      child: const FaqsView(),
    );
  }
}
