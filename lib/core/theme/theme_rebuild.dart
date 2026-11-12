import 'package:flutter/widgets.dart';

/// Re-runs every `build` below it when the app's theme mode changes.
///
/// Same disease [LocaleRebuild] cures for the language, one file over: every
/// route hands the tree a `const` page, and Flutter skips the update of a
/// child whose new widget instance is identical to the one it already holds.
/// Screens that pick their colours from `Theme.of(context)` repaint on a
/// `themeMode` change by themselves; screens that read the `AppColor` roles
/// directly do not, so they keep the light surface they were first built on
/// until this walk marks them dirty.
///
/// Wrap the root (see `app.dart`), one walk covers the whole tree, including
/// dialogs and routes pushed above it. Marking dirty — not remounting — keeps
/// scroll positions, half-typed forms and the navigation stack alive.
class ThemeRebuild extends StatefulWidget {
  const ThemeRebuild({super.key, required this.child});

  final Widget child;

  @override
  State<ThemeRebuild> createState() => _ThemeRebuildState();
}

class _ThemeRebuildState extends State<ThemeRebuild> {
  @override
  void didUpdateWidget(ThemeRebuild oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent (the theme `BlocBuilder`) rebuilt, so the mode changed.
    // Deferred: `markNeedsBuild` is not allowed while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _markTreeDirty(context as Element);
    });
  }

  void _markTreeDirty(Element element) {
    if (element is ComponentElement) element.markNeedsBuild();
    element.visitChildren(_markTreeDirty);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
