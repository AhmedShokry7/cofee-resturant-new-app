import 'package:new_coffee/core/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/main/presentation/manager/main/main_cubit.dart';
import 'package:new_coffee/features/main/presentation/views/widgets/main_bottom_bar.dart';
import 'package:new_coffee/features/main/presentation/views/widgets/main_tabs.dart';
import 'package:new_coffee/features/notifications/data/services/push_service.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

/// The five tabs and the bar between them.
///
/// The shell also owns the two things that can only happen once the app is
/// really on screen: the screen a tapped notification asked for.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  bool _exitDialogOpen = false;

  Future<void> _handleBack() async {
    if (_exitDialogOpen) return;
    _exitDialogOpen = true;
    final isArabic = AppLocale.instance.isArabic;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(AppIcons.logout),
        title: Text(isArabic ? 'الخروج من التطبيق' : 'Exit the app?'),
        content: Text(
          isArabic
              ? 'هل تريد إغلاق التطبيق الآن؟'
              : 'Would you like to close the app now?',
        ),
        actions: [
          CustomTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(isArabic ? 'البقاء' : 'Stay'),
          ),
          CustomBtn(
            width: AppSizes.px96,
            height: AppSizes.px40,
            text: isArabic ? 'خروج' : 'Exit',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (shouldExit == true) await SystemNavigator.pop();
  }

  @override
  void initState() {
    super.initState();
    // Wait for the first frame so a notification can navigate from a ready
    // navigator.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // A push that opened the app waits here, because there was no navigator
      // to show its screen when the tap arrived. The main page is the last stop
      // of the splash, so this is the first moment the screen can be shown.
      final route = PushService.takePendingRoute();
      if (route != null) {
        Navigator.of(context)
            .pushNamed(route.route, arguments: route.arguments);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = buildMainTabs();
    return BlocBuilder<MainCubit, MainState>(
      builder: (context, state) {
        return PopScope<void>(
          canPop: ModalRoute.of(context)?.canPop ?? true,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBack();
          },
          child: Scaffold(
            // A tab is built only after the customer opens it, and stays built
            // afterwards, so switching away never loses its state.
            body: IndexedStack(
              index: state.index,
              children: [
                for (var i = 0; i < tabs.length; i++)
                  state.isBuilt(i) ? tabs[i].page : const SizedBox.shrink(),
              ],
            ),
            bottomNavigationBar: MainBottomBar(
              tabs: tabs,
              currentIndex: state.index,
              onTap: (index) => context.read<MainCubit>().changeTab(index),
            ),
          ),
        );
      },
    );
  }
}
