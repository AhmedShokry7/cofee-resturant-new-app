import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    this.name,
    this.email,
  });

  final String id;
  final String? name;
  final String? email;
}
