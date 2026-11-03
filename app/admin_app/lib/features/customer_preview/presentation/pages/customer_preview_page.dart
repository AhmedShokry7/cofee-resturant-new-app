import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/customer_preview_cubit.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/customer_preview_state.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/customer_preview_rail.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/phone_frame.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_viewport.dart';
import 'package:admin_app/shared/widgets/admin_page_title.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

/// محاكي تطبيق العميل داخل اللوحة.
///
/// الصفحة طريق وحالة حياة: تبني الـ cubit وتقرأ، وهي التي تقرّر إن كان عرض
/// الهاتف بجانب السكة أم تحته. قواعد ما يراه الزبون كلها في `CustomerFeed`،
/// وشاشات الهاتف في widgets المحاكي.
class CustomerPreviewPage extends StatefulWidget {
  const CustomerPreviewPage({super.key, this.cubit});

  final CustomerPreviewCubit? cubit;

  @override
  State<CustomerPreviewPage> createState() => _CustomerPreviewPageState();
}

class _CustomerPreviewPageState extends State<CustomerPreviewPage> {
  late final CustomerPreviewCubit _cubit;
  late final bool _ownsCubit;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? CustomerPreviewCubit();
    if (_ownsCubit) _cubit.load();
  }

  @override
  void dispose() {
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CustomerPreviewCubit>.value(
      value: _cubit,
      child: _CustomerPreviewView(cubit: _cubit),
    );
  }
}

class _CustomerPreviewView extends StatelessWidget {
  const _CustomerPreviewView({required this.cubit});

  final CustomerPreviewCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerPreviewCubit, CustomerPreviewState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pageHorizontalPadding,
            vertical: AppDimensions.pageVerticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageTitle(S.customerPreview),
              const SizedBox(height: AppSpacing.lg),
              Expanded(child: _body(context, state, cubit)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    CustomerPreviewState state,
    CustomerPreviewCubit cubit,
  ) {
    if (state.status == CustomerPreviewStatus.failure) {
      return AdminFailureView(message: state.errorMessage, onRetry: cubit.load);
    }
    if (state.feed == null) return const AdminLoadingView();

    final rail = CustomerPreviewRail(
      state: state,
      onRefresh: cubit.load,
      onLanguageChanged: cubit.setPhoneLanguage,
      onBranchChanged: cubit.selectBranch,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = _Phone(
          state: state,
          cubit: cubit,
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
        );
        final wide =
            constraints.maxWidth >=
            AppDimensions.simulatorRailWidth +
                AppDimensions.simulatorScreenWidth +
                AppSpacing.lg;
        if (!wide) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: phone),
                const SizedBox(height: AppSpacing.lg),
                rail,
              ],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: AppDimensions.simulatorRailWidth,
              child: SingleChildScrollView(child: rail),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: SingleChildScrollView(child: Center(child: phone)),
            ),
          ],
        );
      },
    );
  }
}

/// الهاتف بقدر ما تسع اللوحة: لا يكبر عن مقاس شاشة العميل الموثّق، ويصغر حين
/// تضيق المساحة حتى لا تبتلع الشاشة حواف اللوحة.
class _Phone extends StatelessWidget {
  const _Phone({
    required this.state,
    required this.cubit,
    required this.maxWidth,
    required this.maxHeight,
  });

  final CustomerPreviewState state;
  final CustomerPreviewCubit cubit;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      width: PhoneFrame.widthFitting(maxWidth: maxWidth, maxHeight: maxHeight),
      child: SimulatorViewport(
        state: state,
        onSelectTab: cubit.selectTab,
        onSelectCategory: cubit.selectCategory,
        onSearchChanged: cubit.updateQuery,
        onRefresh: cubit.load,
      ),
    );
  }
}
