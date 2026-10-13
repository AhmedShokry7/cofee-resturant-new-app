import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
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
  final _nameController = TextEditingController(text: "Ahmed Shokry");
  final _emailController = TextEditingController(text: "user@example.com");
  final _phoneController = TextEditingController(text: "+966 50 123 4567");

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
      messenger.showSnackBar(
        const SnackBar(content: Text("Profile updated successfully")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Your Profile")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(SpacingTokens.lg.w),
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
              hint: "Full Name",
              keyboardType: TextInputType.name,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? "Name is required"
                  : null,
            ),
            CustomTextFormField(
              controller: _emailController,
              hint: "Email",
              keyboardType: TextInputType.emailAddress,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? "Email is required"
                  : null,
            ),
            CustomTextFormField(
              controller: _phoneController,
              hint: "Phone Number",
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? "Phone is required"
                  : null,
            ),
            SizedBox(height: SpacingTokens.lg.h),
            CustomBtn(text: "Save", onPressed: _save),
          ],
        ),
      ),
    );
  }
}
