import 'package:catcher/core/catcher.dart';
import 'package:flutter/widgets.dart';

class NavigationService {
  NavigationService._();
  factory NavigationService() => _instance;

  static final _instance = NavigationService._();
  static final GlobalKey<NavigatorState> navigatorKey = Catcher.navigatorKey;

  OverlayState get overlay => navigatorKey.currentState.overlay;
  BuildContext get context => navigatorKey.currentState.context;

  Future<T> pushReplacementNamed<T extends Object>(
    String path, {
    Object arguments,
  }) =>
      navigatorKey.currentState.pushReplacementNamed<T, T>(
        path,
        arguments: arguments,
      );
}
