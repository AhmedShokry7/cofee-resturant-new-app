import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';

class PreviewSurface extends StatelessWidget {
  const PreviewSurface({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(S.previewUnsupported));
  }
}
