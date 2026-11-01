import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The phone window a widget test renders a screen into.
///
/// It is the narrowest shape the app ships to, so a layout that passes here
/// passes everywhere; a screen that needs more room gets its own
/// `logicalSize` argument rather than a second number written into the test.
const Size phoneViewport = Size(360, 690);

/// A tablet in portrait: wide enough that the content grids must gain columns.
const Size tabletViewport = Size(800, 1024);

/// The same window at a 3x device pixel ratio, for a test that has to set
/// `physicalSize` directly.
const double phoneDevicePixelRatio = 3;

/// The columns a laid-out grid really drew, counted from the tile left edges.
///
/// The catalog grids count their own columns from the window now, so
/// `crossAxisCount` is no longer a number a test can read off the delegate.
int columnCount(Finder tiles) {
  final lefts = <double>{};
  for (final tile in tiles.evaluate()) {
    final box = tile.renderObject;
    if (box is! RenderBox) continue;
    lefts.add(box.localToGlobal(Offset.zero).dx);
  }
  return lefts.length;
}
