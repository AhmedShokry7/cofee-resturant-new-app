import 'package:flutter/material.dart';

class PreviewDraftSettings {
  const PreviewDraftSettings({
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.surfaceColor,
  });

  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color surfaceColor;

  static const PreviewDraftSettings defaults = PreviewDraftSettings(
    primaryColor: Color(0xFF1D4ED8),
    secondaryColor: Color(0xFF033A58),
    backgroundColor: Color(0xFFFFFFFF),
    surfaceColor: Color(0xFFF9F9F9),
  );

  PreviewDraftSettings copyWith({
    Color? primaryColor,
    Color? secondaryColor,
    Color? backgroundColor,
    Color? surfaceColor,
  }) {
    return PreviewDraftSettings(
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PreviewDraftSettings &&
      other.primaryColor == primaryColor &&
      other.secondaryColor == secondaryColor &&
      other.backgroundColor == backgroundColor &&
      other.surfaceColor == surfaceColor;

  @override
  int get hashCode => Object.hash(
        primaryColor,
        secondaryColor,
        backgroundColor,
        surfaceColor,
      );
}
