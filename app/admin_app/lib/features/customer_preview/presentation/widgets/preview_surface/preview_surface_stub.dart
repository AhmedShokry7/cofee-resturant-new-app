import 'package:flutter/material.dart';

class PreviewSurface extends StatelessWidget {
  const PreviewSurface({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Preview is available on web builds.'),
    );
  }
}
