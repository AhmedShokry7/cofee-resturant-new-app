import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/profile/presentation/manager/account_details/account_details_cubit.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/change_password_dialog.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/edit_profile_form.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';

/// The account form: fills itself from the cubit's read, sends the cubit's two
/// writes, and says what happened.
///
/// The account is read once through [AccountDetailsCubit] and the fields are
/// filled from that read, never re-filled after the customer starts typing, so a
/// slow response cannot overwrite what was just written.
class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
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

  /// Asks for the three password entries, then moves the account's password.
  Future<void> _changePassword() async {
    final change = await showChangePasswordDialog(context);
    if (change == null || !mounted) return;
    // A refusal is already on screen through the cubit's error; only the
    // success needs a word here.
    final changedOnServer = await context
        .read<AccountDetailsCubit>()
        .changePassword(
          oldPassword: change.oldPassword,
          newPassword: change.newPassword,
        );
    if (!changedOnServer || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.passwordChanged)));
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
            .showSnackBar(SnackBar(content: Text(state.errorCopy!)));
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
              return EmptyState(
                icon: AppIcons.user,
                title: S.couldNotLoadAccountDetails,
                actionLabel: S.retry,
                onAction: () => context.read<AccountDetailsCubit>().load(),
              );
            }
            _seedFromAccount(state);
            return EditProfileForm(
              formKey: _formKey,
              firstName: _firstNameController,
              lastName: _lastNameController,
              email: _emailController,
              phone: _phoneController,
              isSaving: state.isSaving,
              isChangingPassword: state.isChangingPassword,
              onSave: _save,
              onChangePassword: _changePassword,
            );
          },
        ),
      ),
    );
  }
}
