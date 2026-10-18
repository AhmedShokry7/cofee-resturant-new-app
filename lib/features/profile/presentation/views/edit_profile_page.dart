import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  static const routeName = "editProfileRoute";

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fillFromAccount();
  }

  Future<void> _fillFromAccount() async {
    try {
      final user = await context.read<AuthRepository>().currentUser();
      if (!mounted) return;
      final parts = (user?.name ?? '').trim().split(RegExp(r'\s+'));
      _firstNameController.text = parts.isNotEmpty ? parts.first : '';
      _lastNameController.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      _emailController.text = user?.email ?? '';
      _phoneController.text = user?.phone ?? '';
    } catch (_) {
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _showChangePasswordDialog() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final changed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تغيير كلمة المرور'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
                  validator: (value) =>
                      (value == null || value.trim().length < 6) ? '6 أحرف على الأقل' : null,
                ),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
                  validator: (value) => value != newPasswordController.text ? 'غير متطابقة' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('إلغاء')),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) Navigator.of(dialogContext).pop(true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
      if (changed != true || !mounted) return;
      await context.read<AuthRepository>().changePassword(newPassword: newPasswordController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تغيير كلمة المرور')));
    } finally {
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();
      await context.read<AuthRepository>().updateProfile(
        fullName: fullName.isEmpty ? (_firstNameController.text.trim()) : fullName,
        phone: _phoneController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.profileUpdated)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.profileUpdateFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.yourProfile)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            SpacingTokens.lg.w,
            SpacingTokens.md.h,
            SpacingTokens.lg.w,
            SpacingTokens.lg.w,
          ),
          children: [
            CustomTextFormField(
              controller: _firstNameController,
              hint: S.firstNameHint,
              keyboardType: TextInputType.name,
              validator: (value) => (value == null || value.trim().isEmpty) ? S.nameRequired : null,
            ),
            CustomTextFormField(
              controller: _lastNameController,
              hint: S.lastNameHint,
              keyboardType: TextInputType.name,
            ),
            CustomTextFormField(
              controller: _emailController,
              hint: S.emailHint,
              keyboardType: TextInputType.emailAddress,
            ),
            CustomTextFormField(
              controller: _phoneController,
              hint: S.phoneNumberHint,
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: SpacingTokens.lg.h),
            CustomBtn(text: S.save, onPressed: _saving ? null : _save),
            SizedBox(height: SpacingTokens.md.h),
            OutlinedButton(
              onPressed: _showChangePasswordDialog,
              child: const Text('تغيير كلمة المرور'),
            ),
          ],
        ),
      ),
    );
  }
}
