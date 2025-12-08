import 'package:flutter/material.dart';

/// Responsive utility klasė, kuri prisitaiko prie ekrano dydžio
class ResponsiveUtils {
  static late double _screenWidth;
  static late double _screenHeight;

  // Baziniai dydžiai (pagal 375px pločio ekraną - iPhone SE/8)
  static const double _baseWidth = 375.0;
  static const double _baseHeight = 812.0;

  /// Inicializuoti su context (kviesti kiekvieno ekrano pradžioje)
  static void init(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    _screenWidth = mediaQuery.size.width;
    _screenHeight = mediaQuery.size.height;
  }

  /// Ekrano plotis
  static double get screenWidth => _screenWidth;

  /// Ekrano aukštis
  static double get screenHeight => _screenHeight;

  /// Proporcinis plotis (pagal bazinį 375px)
  static double width(double size) {
    return (size / _baseWidth) * _screenWidth;
  }

  /// Proporcinis aukštis (pagal bazinį 812px)
  static double height(double size) {
    return (size / _baseHeight) * _screenHeight;
  }

  /// Proporcinis šrifto dydis (su min/max ribomis)
  static double fontSize(double size) {
    double scaledSize = (size / _baseWidth) * _screenWidth;

    // Minimalus ir maksimalus dydis (apsauga nuo per mažų/didelių šriftų)
    double minSize = size * 0.8; // Ne mažiau nei 80% originalaus
    double maxSize = size * 1.3; // Ne daugiau nei 130% originalaus

    return scaledSize.clamp(minSize, maxSize);
  }

  /// Proporcinis padding/margin
  static double space(double size) {
    return (size / _baseWidth) * _screenWidth;
  }

  /// Proporcinis ikonos dydis
  static double iconSize(double size) {
    double scaledSize = (size / _baseWidth) * _screenWidth;
    return scaledSize.clamp(size * 0.7, size * 1.4);
  }

  // ============ STANDARTINIAI DYDŽIAI ============

  /// Labai mažas šriftas (pvz., hints, labels)
  static double get fontXS => fontSize(10);

  /// Mažas šriftas (pvz., secondary text)
  static double get fontS => fontSize(12);

  /// Normalus šriftas (pvz., body text)
  static double get fontM => fontSize(14);

  /// Vidutinis-didelis šriftas (pvz., subtitles)
  static double get fontL => fontSize(16);

  /// Didelis šriftas (pvz., titles)
  static double get fontXL => fontSize(20);

  /// Labai didelis šriftas (pvz., headers)
  static double get fontXXL => fontSize(28);

  // ============ STANDARTINIAI TARPAI ============

  /// Mažas tarpas (4px bazėje)
  static double get spaceXS => space(4);

  /// Vidutinis-mažas tarpas (8px bazėje)
  static double get spaceS => space(8);

  /// Normalus tarpas (12px bazėje)
  static double get spaceM => space(12);

  /// Vidutinis-didelis tarpas (16px bazėje)
  static double get spaceL => space(16);

  /// Didelis tarpas (20px bazėje)
  static double get spaceXL => space(20);

  /// Labai didelis tarpas (32px bazėje)
  static double get spaceXXL => space(32);

  // ============ STANDARTINĖS IKONOS ============

  /// Maža ikona
  static double get iconS => iconSize(16);

  /// Normali ikona
  static double get iconM => iconSize(24);

  /// Didelė ikona
  static double get iconL => iconSize(32);

  /// Labai didelė ikona (pvz., logo)
  static double get iconXL => iconSize(48);

  /// Hero ikona (pvz., pagrindinis paveikslėlis)
  static double get iconXXL => iconSize(80);

  // ============ PAGALBINĖS FUNKCIJOS ============

  /// Ar tai mažas ekranas? (< 360px)
  static bool get isSmallScreen => _screenWidth < 360;

  /// Ar tai vidutinis ekranas? (360-400px)
  static bool get isMediumScreen => _screenWidth >= 360 && _screenWidth < 400;

  /// Ar tai didelis ekranas? (>= 400px)
  static bool get isLargeScreen => _screenWidth >= 400;

  /// Ar tai planšetė? (>= 600px)
  static bool get isTablet => _screenWidth >= 600;
}
