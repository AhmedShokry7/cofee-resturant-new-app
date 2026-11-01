import 'package:flutter/material.dart';

import 'package:new_coffee/features/content/presentation/views/widgets/content_failure_view.dart';

/// The frame every content screen shares: app bar, and the choice between the
/// skeleton, the failure state and the loaded body.
///
/// The loading widget is passed in because each screen has its own skeleton,
/// which mirrors that screen's own layout.
class ContentPageShell extends StatelessWidget {
  const ContentPageShell({
    super.key,
    required this.title,
    required this.isLoading,
    required this.loadingView,
    required this.failureMessage,
    required this.onRetry,
    required this.contentBuilder,
  });

  final String title;
  final bool isLoading;

  /// Shown while [isLoading], and only then.
  final Widget loadingView;

  /// What to tell the customer about the failed read; null when there is
  /// nothing to report. The raw error never reaches the screen.
  final String? failureMessage;
  final VoidCallback onRetry;

  /// The loaded screen, run only once the read settled without an error.
  final WidgetBuilder contentBuilder;

  @override
  Widget build(BuildContext context) {
    final String? error = failureMessage;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: isLoading
          ? loadingView
          : error != null
          ? ContentFailureView(message: error, onRetry: onRetry)
          : contentBuilder(context),
    );
  }
}
