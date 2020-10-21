import 'package:SarSys/core/app_controller.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class NavigationService extends Service {
  NavigationService._();
  factory NavigationService() => _instance;

  static final _instance = NavigationService._();
  static final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  static GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  static bool get isReady => _navigatorKey?.currentState != null;

  OverlayState get overlay => navigatorKey.currentState.overlay;
  BuildContext get context => navigatorKey.currentContext;

  AppController get controller => Provider.of<AppController>(context);

  void overlayPop() => Navigator.pop(navigatorKey.currentState.overlay.context);

  Future<T> pushReplacementNamed<T extends Object>(
    String path, {
    Object arguments,
  }) =>
      navigatorKey.currentState.pushReplacementNamed<T, T>(
        path,
        arguments: arguments,
      );
}
