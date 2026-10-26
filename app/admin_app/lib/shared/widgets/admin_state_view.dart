import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';

/// The spinner a page shows while its first load is running.
class AdminLoadingView extends StatelessWidget {
  const AdminLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// The message a page shows when the first load failed, with a retry.
///
/// Every feature reuses it so a failure looks and behaves the same way
/// across the dashboard.
class AdminFailureView extends StatelessWidget {
  const AdminFailureView({super.key, required this.message, this.onRetry});

  /// The error the repository reported, when there is one to show.
  final String? message;

  /// Reloads the data of the page.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(message!, textAlign: TextAlign.center),
            ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: onRetry, child: Text(S.retry)),
          ],
        ],
      ),
    );
  }
}
