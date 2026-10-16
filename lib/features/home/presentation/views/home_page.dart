import 'package:flutter/material.dart';
import 'package:new_coffee/features/assistant/presentation/widgets/assistant_fab.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_page_body.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // The assistant lives in this scaffold's FAB slot, so it appears only
    // on the Home tab and floats above the bottom navigation without
    // covering content.
    return const Scaffold(
      body: HomePageBody(),
      floatingActionButton: AssistantFab(),
    );
  }
}
