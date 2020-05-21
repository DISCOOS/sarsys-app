import 'package:SarSys/controllers/bloc_controller.dart';
import 'package:catcher/core/catcher.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class NavigationService {
  NavigationService._();
  factory NavigationService() => _instance;

  static final _instance = NavigationService._();
  static final GlobalKey<NavigatorState> _navigatorKey = Catcher.navigatorKey;
  static GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  OverlayState get overlay => navigatorKey.currentState.overlay;
  BuildContext get context => navigatorKey.currentContext;

  BlocController get controller => Provider.of<BlocController>(context);

  Future<T> pushReplacementNamed<T extends Object>(
    String path, {
    Object arguments,
  }) =>
      navigatorKey.currentState.pushReplacementNamed<T, T>(
        path,
        arguments: arguments,
      );
}
