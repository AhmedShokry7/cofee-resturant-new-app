import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/core/services/supabase_service.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/data/model/auth_form_rules.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/forget_password_page.dart';
import 'package:new_coffee/features/auth/presentation/views/sign_up_page.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_design.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_spacings.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_social_login.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_switch_prompt.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/shared/widgets/auth_message_dialog.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';
import 'package:new_coffee/shared/widgets/skip_btn.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class LoginPageBody extends StatefulWidget {
  const LoginPageBody({super.key});

  @override
  State<LoginPageBody> createState() => _LoginPageBodyState();
}

class _LoginPageBodyState extends State<LoginPageBody> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthCubit>().signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  /// Hands the customer over to wherever they were going.
  ///
  /// The [AuthCubit] already decided this (and wrote the session marker); only
  /// the *where* is resolved here, because it depends on the route this page
  /// was pushed with, which lives in the widget tree.
  void _onAuthenticated() {
    // Preview starts on a synthetic splash route. Returning to it would strand
    // the customer there, so a successful preview login opens the real store.
    if (SupabaseService.isPreviewMode) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(MainPage.routeName, (route) => false);
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      final origin = ModalRoute.of(context)?.settings.arguments;
      if (origin is String && origin.isNotEmpty) {
        Navigator.of(context).pushReplacementNamed(origin);
      } else {
        _goToStore();
      }
    }
  }

  void _onSkipped() => _goToStore();

  void _goToStore() {
    Navigator.of(context).pushReplacementNamed(MainPage.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: BlocConsumer<AuthCubit, AuthState>(
              listener: (context, state) {
                if (state is AuthFailure) {
                  AuthMessageDialog.show(
                    context,
                    type: AuthMessageType.error,
                    message: state.message,
                  );
                } else if (state is AuthSuccess) {
                  _onAuthenticated();
                } else if (state is AuthSkipped) {
                  _onSkipped();
                }
              },
              builder: (context, state) {
                final isLoading = state is AuthLoading;
                // الطبقة المنشورة فوق أصل الشاشة: نصّ منشور يعلو، وإخفاء
                // منشور يُسقط المكوّن. غياب الطبقة يعني الشاشة كما رسمها
                // المصدر.
                final title = AuthNative.title(context, 'auth');
                final subtitle = AuthNative.subtitle(context, 'auth');
                final social = AuthNative.of(
                  context,
                  'auth',
                  DesignWidgetTypes.authSocial,
                );
                final switchPrompt = AuthNative.of(
                  context,
                  'auth',
                  DesignWidgetTypes.authSwitchPrompt,
                );
                return Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The pinned skip control owns this band.
                      const SizedBox(height: AppDimensions.skipReservedHeight),
                      if (title?.visible ?? true)
                        Text(
                          title?.text ?? S.signIn,
                          textAlign: TextAlign.center,
                          style: AppFonts.semiBold24(context),
                        ),
                      SizedBox(height: AuthSpacings.titleGap),
                      if (subtitle?.visible ?? true)
                        Text(
                          subtitle?.text ?? S.welcomeBackSubtitle,
                          textAlign: TextAlign.center,
                          style: AppFonts.regular14(context)
                              .copyWith(color: AppColor.greyColor),
                        ),
                      SizedBox(height: AuthSpacings.headerGap),
                      CustomTextFormField(
                        showFocusTint: false,
                        controller: _emailController,
                        hint: S.emailHint,
                        icon: AppIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: AuthFormRules.email,
                      ),
                      CustomTextFormField(
                        showFocusTint: false,
                        controller: _passwordController,
                        hint: S.passwordHint,
                        icon: AppIcons.password,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: AuthFormRules.password,
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: CustomTextButton(
                          onPressed: () =>
                              Navigator.of(context)
                                  .pushNamed(ForgetPasswordPage.routeName),
                          child: Text(
                            S.forgotPasswordQ,
                            style: AppFonts.regular12(context).copyWith(
                              color: AppColor.primaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: AuthSpacings.fieldsGap),
                      CustomBtn(
                        text: S.signIn,
                        isLoading: isLoading,
                        onPressed: _submit,
                      ),
                      SizedBox(height: AuthSpacings.buttonGap),
                      if (social?.visible ?? true) ...[
                        AuthSocialLogin(isLoading: isLoading),
                        SizedBox(height: AuthSpacings.sectionGap),
                      ],
                      // A mailbox is the other credential the customer always
                      // carries. It opens on its own, so a number that cannot
                      // be reached — or a Google account that is not on the
                      // device — never leaves the app with no way in.
                      if (switchPrompt?.visible ?? true)
                        AuthSwitchPrompt(
                          question: S.dontHaveAccount,
                          actionText: S.signUp,
                          // The page that asked for sign-in is passed on, so a
                          // customer who picks "create an account" instead of
                          // signing in still ends up back at checkout rather than
                          // dumped on the store home.
                          onTap: () => Navigator.of(context)
                              .pushReplacementNamed(
                                SignUpPage.routeName,
                                arguments: ModalRoute.of(context)
                                    ?.settings
                                    .arguments,
                              ),
                        ),
                      SizedBox(height: AuthSpacings.bottom),
                    ],
                  ),
                );
              },
            ),
          ),
          // The way out of the flow is pinned over the scroller, not inside it:
          // a skip control that scrolls off the top of a long form is no longer
          // a way out.
          SkipBtn(onTap: () => context.read<AuthCubit>().skipAuthentication()),
        ],
      ),
    );
  }
}
