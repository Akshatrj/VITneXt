import 'package:flutter/material.dart';

class AppColors {
  static const Color arOrange = Color(0xFFFF8C42);
  static const Color abBlue = Color(0xFF4C8BF5);
  static const Color ab02Purple = Color(0xFF9C6ADE);
  static const Color lcGreen = Color(0xFF34A853);
  static const Color cbRed = Color(0xFFEA4335);
  static const Color crGrey = Color(0xFF9AA0A6);
  static const Color otherTeal = Color(0xFF00897B);

  static Color getBuildingColor(String buildingCode, [BuildContext? context]) {
    final code = buildingCode;
    Color base;
    if (code.startsWith('AR')) base = arOrange;
    else if (code.startsWith('AB02')) base = ab02Purple;
    else if (code.startsWith('AB')) base = abBlue;
    else if (code.startsWith('LC')) base = lcGreen;
    else if (code.startsWith('CB')) base = cbRed;
    else if (code.startsWith('CR')) base = crGrey;
    else base = otherTeal;

    final isDark = context != null && Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return Color.lerp(base, Colors.white, 0.15) ?? base;
    }
    return base;
  }

  static Color getBuildingColorLight(String buildingCode, [BuildContext? context]) {
    final color = getBuildingColor(buildingCode, context);
    final isDark = context != null && Theme.of(context).brightness == Brightness.dark;
    return Color.lerp(color, isDark ? Colors.white : Colors.white, isDark ? 0.25 : 0.4) ?? color;
  }

  static LinearGradient getBuildingGradient(String buildingCode, [BuildContext? context]) {
    final baseColor = getBuildingColor(buildingCode, context);
    final lightColor = getBuildingColorLight(buildingCode, context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [baseColor, lightColor],
    );
  }

  /// Grid cell background for selected state in dark mode.
  static Color gridSelectionColor(BuildContext context, {required bool isClash}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isClash) {
      return isDark ? Colors.red.shade900.withValues(alpha: 0.7) : Colors.red.shade200;
    }
    return isDark ? Colors.green.shade800.withValues(alpha: 0.6) : Colors.green.shade200;
  }

  static Color gridHeaderColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.colorScheme.surfaceContainerHighest;
  }
}
