import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/preview/preview_section.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/design/data/model/native_section.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/design_section_chrome.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/design_sections.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section.dart';
import 'package:new_coffee/features/welcome/presentation/manager/welcome/welcome_cubit.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_view_text_body.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_view_text_title.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

/// Renders the welcome page's editable elements in their saved tree order.
class WelcomePanelContent extends StatelessWidget {
  const WelcomePanelContent({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = context.select(
      (DesignCubit cubit) => cubit.state.pageSections('welcome'),
    );
    final spacing = nativeSection(sections, DesignWidgetTypes.welcomeSpacing);
    final gap = spacing?.numberProperty('gap') ?? AppSpacing.md;
    final alignment = switch (spacing?.property('contentAlignment')) {
      'start' => MainAxisAlignment.start,
      'center' => MainAxisAlignment.center,
      _ => MainAxisAlignment.end,
    };
    final widgets = <Widget>[];
    var titleRendered = false;

    for (final section in sections) {
      if (!section.visible) continue;
      Widget? widget;
      switch (section.type) {
        case DesignWidgetTypes.welcomeHero:
          // The hero image is positioned behind the panel by WelcomePageBody.
          continue;
        case DesignWidgetTypes.welcomeSpacing:
          // Spacing controls the page layout and is not a visible editor node.
          continue;
        case DesignWidgetTypes.welcomeTitle:
          widget = const WelcomeViewTextTitle();
          titleRendered = true;
        case DesignWidgetTypes.welcomeBody:
          widget = const WelcomeViewTextBody();
        case DesignWidgetTypes.welcomeCta:
          widget = _WelcomeCta(node: section);
        default:
          widget = DesignSectionRenderers.build(section);
      }
      if (widget == null) continue;
      widgets.add(
        previewSectionWrap(
          section,
          pageId: 'welcome',
          child: _WelcomeSection(section: section, child: widget),
        ),
      );
      if (section.type == DesignWidgetTypes.welcomeTitle && gap > 0) {
        widgets.add(SizedBox(height: gap));
      }
    }

    // Older saved designs may have removed the native title; retain the
    // localized default copy so a partially configured page stays usable.
    if (!titleRendered && widgets.isEmpty) {
      widgets.add(const WelcomeViewTextTitle());
      widgets.add(SizedBox(height: gap));
      widgets.add(const WelcomeViewTextBody());
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: alignment,
            mainAxisSize: MainAxisSize.min,
            children: widgets,
          ),
        ),
      ),
    );
  }
}

class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection({required this.section, required this.child});

  final PublishedSection section;
  final Widget child;

  @override
  Widget build(BuildContext context) => HomeSection(
    child: DesignSectionChrome(section: section, child: child),
  );
}

class _WelcomeCta extends StatelessWidget {
  const _WelcomeCta({required this.node});

  final PublishedSection node;

  Color? _color(String key) {
    final value = node.property(key);
    if (value == null ||
        !RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(value)) {
      return null;
    }
    final parsed = int.parse(value.substring(1), radix: 16);
    return value.length == 9 ? Color(parsed) : Color(0xFF000000 | parsed);
  }

  @override
  Widget build(BuildContext context) {
    final label = node.localizedText('label')?.trim();
    return BlocBuilder<WelcomeCubit, WelcomeState>(
      builder: (context, state) => SizedBox(
        width: double.infinity,
        child: CustomBtn(
          text: label == null || label.isEmpty ? S.letsGetStarted : label,
          height: node.numberProperty('height'),
          borderRadius: node.numberProperty('borderRadius'),
          backgroundColor: _color('backgroundColor'),
          textColor: _color('textColor'),
          variant: switch (node.property('style')) {
            'secondary' => BtnVariant.secondary,
            'outlined' => BtnVariant.outlined,
            _ => BtnVariant.primary,
          },
          isLoading: state.isStarting,
          onPressed: () => context.read<WelcomeCubit>().startOnboarding(),
        ),
      ),
    );
  }
}
