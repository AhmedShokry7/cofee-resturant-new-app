import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/content/data/repositories/content_repository.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const routeName = "privacyPolicyRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Privacy Policy")),
      body: FutureBuilder(
        future: context.read<ContentRepository>().legalDocument('privacy'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load policy: ${snapshot.error}'),
            );
          }
          final document = snapshot.data;
          final text = document?.content ?? 'Privacy policy unavailable.';
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              SpacingTokens.lg.w,
              SpacingTokens.md.h,
              SpacingTokens.lg.w,
              SpacingTokens.lg.w,
            ),
            child: Text(
              text,
              style: AppFonts.regular14(context).copyWith(
                color: AppColor.secondryColor,
                height: 1.6,
              ),
            ),
          );
        },
      ),
    );
  }
}
