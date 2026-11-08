import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  // Cores principais
  static const Color primary = Color(0xFF634CD4);
  static const Color glow = Color(0xFF9B79EE);
  static const Color ink = Color(0xFF191928);
  static const Color muted = Color(0xFF676874);

  // Cores de superfície
  static const Color background = Colors.white;
  static const Color inputBackground = Color(0xFFF1F0F7);
  static const Color inputBorder = Color(0xFFE4E0EE);
  static const Color headerBorder = Color(0xFFE4E0FE);

  static const SystemUiOverlayStyle lightPageSystemUi = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  static const SystemUiOverlayStyle darkImageSystemUi = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  // Gradiente principal
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, glow],
  );

  // Gradiente dos cards
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF2EFFF), Color(0xFFEAE5FF), Color(0xFFDDD3FA)],
    stops: [0.0, 0.55, 1.0],
  );

  // Brilho radial dos cards
  static const RadialGradient cardGlow = RadialGradient(
    center: Alignment(-0.85, -0.85),
    radius: 1.15,
    colors: [Color(0xE6FFFFFF), Color(0x80FFFFFF), Color(0x00FFFFFF)],
    stops: [0.0, 0.40, 1.0],
  );

  // Bordas arredondadas
  static const double fieldRadius = 16;
  static const double buttonRadius = 16;
  static const double cardRadius = 28;
}
