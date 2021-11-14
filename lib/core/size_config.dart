

import 'dart:math';

import 'package:flutter/widgets.dart';

class SizeConfig {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;

  static double get screenMin => min(screenWidth, screenHeight);
  static double get screenMax => max(screenWidth, screenHeight);

  static late double safeAreaHorizontal;
  static late double safeAreaVertical;
  static late double safeBlockHorizontal;
  static late double safeBlockVertical;

  static double get labelFontSize => width(3.4);
  static double width(double percent) => (isPortrait ? safeBlockHorizontal : safeBlockVertical) * percent;
  static double height(double percent) => (isPortrait ? safeBlockVertical : safeBlockHorizontal) * percent;

  // static double get labelFontSize => safeBlockHorizontal *
  static Orientation get orientation => _mediaQueryData.orientation;
  static bool get isPortrait => Orientation.portrait == orientation;
  static bool get isLandscape => Orientation.landscape == orientation;

  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;

    safeAreaHorizontal = _mediaQueryData.padding.left + _mediaQueryData.padding.right;
    safeAreaVertical = _mediaQueryData.padding.top + _mediaQueryData.padding.bottom;
    safeBlockHorizontal = (screenWidth - safeAreaHorizontal) / 100;
    safeBlockVertical = (screenHeight - safeAreaVertical) / 100;
  }
}
