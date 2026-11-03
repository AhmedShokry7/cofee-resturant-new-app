import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/auth/data/model/auth_form_rules.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/profile/presentation/manager/account_details/account_details_cubit.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

  static const routeName = "editProfileRoute";

  @override
  Widget build(BuildContext context) {
    // Inside AuthGuard: the form reads and writes a real account, so a customer
    // who is not signed in never starts that read.
    return AuthGuard(
      child: BlocProvider(
        create: (context) =>
            AccountDetailsCubit(repository: context.read<AuthRepository>())
              ..load(),
        child: const _EditProfileView(),
      ),
    );
  }
}

class _EditProfileView extends StatefulWidget {
  const _EditProfileView();

  @override
  State<_EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<_EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  /// Whether the account read has already filled the fields. The customer's own
  /// typing is never overwritten by a later rebuild.
  bool _seeded = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _seedFromAccount(AccountDetailsState state) {
    if (_seeded) return;
    _seeded = true;
    _firstNameController.text = state.firstName;
    _lastNameController.text = state.lastName;
    _emailController.text = state.email ?? '';
    _phoneController.text = state.phone;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cubit = context.read<AccountDetailsCubit>();
    // Both are taken before the pop: once the route is gone this element is
    // deactivated, and looking either of them up through its context throws.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await cubit.save(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim(),
    );
    if (!saved || !mounted) return;
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(S.profileUpdated)));
  }

  Future<void> _showChangePasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final changed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(S.changePassword),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: oldPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: S.currentPasswordHint,
                    prefixIcon: const Icon(AppIcons.password),
                  ),
                  validator: AuthFormRules.password,
                ),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: S.newPasswordHint,
                    prefixIcon: const Icon(AppIcons.password),
                  ),
                  validator: AuthFormRules.newPassword,
                ),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: S.confirmPasswordHint,
                    prefixIcon: const Icon(AppIcons.password),
                  ),
                  validator: (value) => AuthFormRules.confirmPassword(
                    value,
                    newPasswordController.text,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(S.cancel),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: Text(S.save),
            ),
          ],
        ),
      );
      if (changed != true || !mounted) return;
      // A failure is already on screen through the cubit's error; only the
      // success needs a word here.
      final changedOnServer = await context
          .read<AccountDetailsCubit>()
          .changePassword(
            oldPassword: oldPasswordController.text.trim(),
            newPassword: newPasswordController.text.trim(),
          );
      if (!changedOnServer || !mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.passwordChanged)));
    } finally {
      oldPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AccountDetailsCubit, AccountDetailsState>(
      // Only a write needs a message over the top of the form. A read that
      // never landed owns the whole screen, with its own reason and its own
      // retry, and consuming its error here would clear the very state the
      // failure is drawn from.
      listenWhen: (previous, current) =>
          _seeded && current.error != null && current.error != previous.error,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.error!)));
        context.read<AccountDetailsCubit>().clearError();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(S.yourProfile)),
        body: BlocBuilder<AccountDetailsCubit, AccountDetailsState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            // A read that failed is shown as what it is. Filling the form with
            // nothing instead would let the customer save a blank name over
            // their real one and never learn that the read broke.
            if (!_seeded && state.error != null) {
              return _AccountReadFailed(
                onRetry: () => context.read<AccountDetailsCubit>().load(),
              );
            }
            _seedFromAccount(state);
            return Form(
              key: _formKey,
              child: ListView(
                padding: AppLayout.pageBody,
                children: [
                  CustomTextFormField(
                    controller: _firstNameController,
                    hint: S.firstNameHint,
                    icon: AppIcons.user,
                    keyboardType: TextInputType.name,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? S.nameRequired
                        : null,
                  ),
                  CustomTextFormField(
                    controller: _lastNameController,
                    hint: S.lastNameHint,
                    icon: AppIcons.user,
                    keyboardType: TextInputType.name,
                  ),
                  CustomTextFormField(
                    controller: _emailController,
                    hint: S.emailHint,
                    icon: AppIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: true,
                    helper: S.emailNotEditableHere,
                  ),
                  CustomTextFormField(
                    controller: _phoneController,
                    hint: S.phoneNumberHint,
                    icon: AppIcons.smartphone,
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: AppSpacing.lg),
                  CustomBtn(
                    text: S.save,
                    isLoading: state.isSaving,
                    onPressed: _save,
                  ),
                  SizedBox(height: AppSpacing.md),
                  CustomBtn(
                    text: S.changePassword,
                    variant: BtnVariant.outlined,
                    isLoading: state.isChangingPassword,
                    onPressed: _showChangePasswordDialog,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AccountReadFailed extends StatelessWidget {
  const _AccountReadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              S.couldNotLoadAccountDetails,
              textAlign: TextAlign.center,
              style: AppFonts.regular14(context),
            ),
            SizedBox(height: AppSpacing.md),
            TextButton(onPressed: onRetry, child: Text(S.retry)),
          ],
        ),
      ),
    );
  }
}
