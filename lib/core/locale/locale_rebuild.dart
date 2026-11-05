import 'package:flutter/widgets.dart';

import 'package:new_coffee/core/locale/app_locale.dart';

/// Re-runs every `build` below it when the app language changes.
///
/// `S` reads the language at build time, so a screen only changes language if
/// its `build` actually runs again. Flutter skips the update of a child whose
/// new widget instance is identical to the instance it already has — which is
/// exactly what `const SomePage()` hands the tree at every route builder in
/// `core/navigation/app_routes.dart` and every tab in `main_tabs.dart`.
/// Rebuilding `MaterialApp` on a language change therefore leaves those
/// subtrees, and the language they were first built in, on screen until the
/// app restarts.
///
/// Marking each component dirty re-runs its build regardless of instance
/// identity, so the copy follows the chosen language *and* the state the
/// customer is standing on — scroll position, a half-typed form, the chosen
/// branch — survives, which a remount or a restart would throw away.
///
/// Wrap the root of the app (see `app.dart`), not individual pages: one walk
/// covers the whole tree, including dialogs and routes pushed above it.
class LocaleRebuild extends StatefulWidget {
  const LocaleRebuild({super.key, required this.child});

  final Widget child;

  @override
  State<LocaleRebuild> createState() => _LocaleRebuildState();
}

class _LocaleRebuildState extends State<LocaleRebuild> {
  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_relocalize);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_relocalize);
    super.dispose();
  }

  /// Deferred to the end of the frame: `markNeedsBuild` is not allowed while
  /// the tree is being built, and the language is switched from a tap.
  void _relocalize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      markEveryWidgetDirty(context as Element);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Marks every component below [element] dirty, depth first.
///
/// Exposed for the guard test: a subtree that is not walked is a subtree that
/// keeps speaking the language the customer left.
@visibleForTesting
void markEveryWidgetDirty(Element element) {
  if (element is ComponentElement) element.markNeedsBuild();
  element.visitChildren(markEveryWidgetDirty);
}
