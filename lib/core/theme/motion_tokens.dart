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

  /// A control changing colour for its own state: focus, press, disabled.
  ///
  /// Shorter than [entrance] on purpose - it answers an action the customer
  /// already took, so it must register rather than arrive.
  static const Duration stateChange = Duration(milliseconds: 200);

  /// How long a page indicator's dots take to change shape. It is shorter than
  /// [entrance] on purpose: the row has to be settled before the page it
  /// describes arrives, or the two look out of step.
  static const Duration dotMorph = Duration(milliseconds: 220);

  /// A page moving under the customer's finger, or under the app's own timer.
  ///
  /// Roughly a third of a second is the ceiling before a slide reads as a wait
  /// rather than a cut, and it pairs with [entranceCurve] so the movement starts
  /// the moment it is asked for instead of easing in.
  static const Duration pageSlide = Duration(milliseconds: 280);

  /// How long an auto-advancing carousel holds one page before moving on.
  ///
  /// Long enough to read a banner's picture and its headline, short enough that
  /// a customer who is not interested is back at the content within a beat.
  static const Duration carouselHold = Duration(seconds: 5);

  /// How long a row that walks on its own stays where the customer left it
  /// before it starts again.
  ///
  /// They stopped it to read something, so the pause has to outlast that look -
  /// a row that slid off while their finger was still on the glass would move
  /// out from under them.
  static const Duration marqueeResumeHold = Duration(milliseconds: 2500);
}
