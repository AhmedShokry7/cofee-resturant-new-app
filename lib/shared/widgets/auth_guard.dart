import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/sign_up_page.dart';

/// Reusable guard for routes and pages that require an authenticated customer.
///
/// Guests see a standard prompt instead of an empty or data-loading page.
class AuthGuard extends StatelessWidget {
  const AuthGuard({super.key, required this.child, this.originRoute});

  final Widget child;
  final String? originRoute;

  @override
  Widget build(BuildContext context) {
    if (SupabaseService.isSignedIn) return child;

    final origin = originRoute ?? ModalRoute.of(context)?.settings.name;
    return AuthRequiredView(originRoute: origin);
  }
}

/// Standard unauthenticated prompt.
class AuthRequiredView extends StatelessWidget {
  const AuthRequiredView({super.key, this.originRoute});

  final String? originRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(S.signInRequired),
              const SizedBox(height: AppSpacing.sm),
              Text(S.signInOrCreateAccount),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context)
                        .pushNamed(AuthPage.routeName, arguments: originRoute),
                child: Text(S.signIn),
              ),
              TextButton(
                onPressed: () => Navigator.of(context)
                    .pushNamed(SignUpPage.routeName, arguments: originRoute),
                child: Text(S.createAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
