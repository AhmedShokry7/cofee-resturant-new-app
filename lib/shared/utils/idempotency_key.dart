import 'dart:math';

/// A token that tells the backend "this is the same intent, not a second one".
abstract final class IdempotencyKey {
  IdempotencyKey._();

  /// Random rather than a clock reading: two intents created in the same
  /// microsecond would otherwise share a key, and the server would treat the
  /// second deduction as a duplicate of the first.
  static String create() {
    final random = Random.secure();
    return List<String>.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
      growable: false,
    ).join();
  }
}
