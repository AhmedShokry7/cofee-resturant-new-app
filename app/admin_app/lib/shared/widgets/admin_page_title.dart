import 'package:flutter/material.dart';

/// The big title every feature page shows above its content.
class AdminPageTitle extends StatelessWidget {
  const AdminPageTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
