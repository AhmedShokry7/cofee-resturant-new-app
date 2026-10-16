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
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Prefill from the signed-in account, never from demo constants.
    _fillFromAccount();
  }

  Future<void> _fillFromAccount() async {
    try {
      final user = await context.read<AuthRepository>().currentUser();
      if (!mounted) return;
      _nameController.text = user?.name ?? '';
      _emailController.text = user?.email ?? '';
    } catch (_) {
      // Leave the fields empty rather than inventing values.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(S.profileUpdated)));
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
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 52.w,
                    backgroundColor: AppColor.lightGreyColor,
                    child: Icon(
                      HugeIcons.strokeRoundedUser,
                      size: 52.w,
                      color: AppColor.greyColor,
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      height: 36.w,
                      width: 36.w,
                      decoration: BoxDecoration(
                        color: AppColor.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColor.whiteColor,
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        HugeIcons.strokeRoundedCamera01,
                        size: 18.w,
                        color: AppColor.whiteColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: SpacingTokens.xl.h),
            CustomTextFormField(
              controller: _nameController,
              hint: S.fullNameHint,
              keyboardType: TextInputType.name,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? S.nameRequired
                  : null,
            ),
            CustomTextFormField(
              controller: _emailController,
              hint: S.emailHint,
              keyboardType: TextInputType.emailAddress,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? S.emailRequired
                  : null,
            ),
            CustomTextFormField(
              controller: _phoneController,
              hint: S.phoneNumberHint,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? S.phoneRequired
                  : null,
            ),
            SizedBox(height: SpacingTokens.lg.h),
            CustomBtn(text: S.save, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
