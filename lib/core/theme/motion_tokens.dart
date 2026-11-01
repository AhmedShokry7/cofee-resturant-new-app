import 'package:flutter/animation.dart';

/// The lengths and curves a transition in the app is allowed to take.
///
/// Screen code kept restating its own milliseconds, so a screen could end up
/// slower than the UI it hands over to. Anything with the same feel picks from
/// here instead of writing a fresh literal.
class MotionTokens {
  /// An entrance the customer watches: a fade, a scale, or both together.
  static const Duration entrance = Duration(milliseconds: 300);

  /// The curve that belongs with [entrance]: it arrives quickly and settles.
  static const Curve entranceCurve = Curves.easeOutCubic;
}
