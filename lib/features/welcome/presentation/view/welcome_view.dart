import 'package:flutter/material.dart';
import 'package:new_coffee/features/welcome/presentation/view/widgets/welcome_page_body.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  static const routeName = "welcomeView";

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: WelcomePageBody());
  }
}
