

import 'package:SarSys/core/page_state.dart';
import 'package:SarSys/core/presentation/widgets/app_drawer.dart';
import 'package:flutter/material.dart';

import 'models/route_model.dart';

abstract class Screen<S extends ScreenState> extends StatefulWidget {
  const Screen({Key? key}) : super(key: key);
  @override
  S createState();
}

abstract class ScreenState<S extends StatefulWidget, T> extends RouteWriter<S, T> {
  final String? title;
  final bool withDrawer;

  final FloatingActionButtonLocation floatingActionButtonLocation;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  final bool routeWriter;

  ScreenState({
    required this.title,
    this.withDrawer = true,
    this.routeWriter = true,
    this.floatingActionButtonLocation = FloatingActionButtonLocation.endFloat,
  });

  @protected
  List<Widget> buildAppBarActions() => <Widget>[];

  @protected
  Widget? buildFAB(BuildContext context) => null;

  @protected
  Widget? bottomNavigationBar(BuildContext context) => null;

  @protected
  Widget buildBody(BuildContext context, BoxConstraints constraints);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Scaffold(
          key: _scaffoldKey,
          drawer: withDrawer ? AppDrawer() : null,
          appBar: AppBar(
            title: Text(title!),
            centerTitle: false,
            actions: buildAppBarActions(),
          ),
          extendBody: true,
          body: buildBody(context, constraints),
          floatingActionButtonLocation: floatingActionButtonLocation,
          floatingActionButton: buildFAB(context),
          bottomNavigationBar: bottomNavigationBar(context),
        );
      },
    );
  }

  void showMessage(
    String message, {
    String action = "OK",
    VoidCallback? onPressed,
    dynamic data,
  }) {
    final snackbar = SnackBar(
      duration: Duration(seconds: 2),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(message),
      ),
      action: _buildSnackBarAction(action, () {
        if (onPressed != null) onPressed();
        ScaffoldMessenger.of(context)..hideCurrentSnackBar(reason: SnackBarClosedReason.action);
      }) as SnackBarAction?,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackbar);
  }

  Widget _buildSnackBarAction(String label, VoidCallback onPressed) {
    return SnackBarAction(
      label: label,
      onPressed: onPressed,
    );
  }
}

/// Utility class for writing current route to PageStorage
abstract class RouteWriter<S extends StatefulWidget, T> extends State<S> with RouteAware {
  static const STATE = "route";
  static const FIELD_DATA = "data";
  static const FIELD_NAME = "name";
  static RouteObserver<PageRoute>? _observer;
  static get observer => _observer ??= RouteObserver<PageRoute>();

  RouteWriter({this.routeData, this.routeName, this.routeWriter = true});

  T? routeData;
  String? routeName;
  bool routeWriter = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      _observer!.subscribe(this, ModalRoute.of(context) as PageRoute<dynamic>);
    }
  }

  @override
  void dispose() {
    _observer!.unsubscribe(this);
    super.dispose();
  }

  /// Called when the top route has been popped off, and the current route
  /// shows up.
  @override
  void didPopNext() {
    writeRoute(data: routeData);
  }

  /// Called when the current route has been pushed.
  @override
  void didPush() {
    writeRoute(data: routeData);
  }

  /// Called when a new route has been pushed, and the current route is no
  /// longer visible.
  @override
  void didPushNext() {}

  /// Called when the current route has been popped off.
  @override
  void didPop() {}

  /// Get current state
  static RouteModel state(BuildContext context) => RouteModel.fromJson(getPageState(context, STATE));

  /// Write route information to PageStorage
  void writeRoute({T? data, String? name}) {
    if (routeWriter) {
      this.routeData = data;
      this.routeName = name ?? this.routeName;
      final route = this.routeName ?? ModalRoute.of(context)?.settings?.name;
      if (route != '/') {
        putPageState(context, STATE, {
          'name': route,
          'data': data,
        });
      }
    }
  }
}
