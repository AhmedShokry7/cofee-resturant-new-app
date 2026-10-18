/// Why the device position could not be used.
///
/// Every case needs a different action from the customer, so they are kept
/// separate rather than collapsing into one shared apology. The
/// permanently-denied case in particular: the system dialog will never appear
/// again, so only Settings can fix it — which is why the UI offers a button
/// that opens them.
enum LocationFailure {
  /// Location services are off at the OS level.
  servicesDisabled,

  /// The customer said no to the permission prompt.
  permissionDenied,

  /// The customer said no, and the OS will not ask again.
  permissionPermanentlyDenied,

  /// No fix arrived within the platform's time limit; usually no GPS indoors.
  timeout,

  /// Anything else the platform reported.
  unavailable,
}