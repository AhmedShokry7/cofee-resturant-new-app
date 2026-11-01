import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/features/assistant/presentation/widgets/assistant_fab.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/current_user/current_user_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_page_body.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // The assistant lives in this scaffold's FAB slot, so it appears only
    // on the Home tab and floats above the bottom navigation without
    // covering content.
    return BlocProvider(
      create: (context) =>
          CurrentUserCubit(repository: context.read<AuthRepository>())..load(),
      child: const Scaffold(
        body: HomePageBody(),
        floatingActionButton: AssistantFab(),
      ),
    );
  }
}
