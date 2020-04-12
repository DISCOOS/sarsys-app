import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/core/app_state.dart';
import 'package:SarSys/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'models/route_model.dart';

abstract class Screen<S extends ScreenState> extends StatefulWidget {
  const Screen({Key key}) : super(key: key);
  @override
  S createState();
}

abstract class ScreenState<S extends StatefulWidget, T> extends RouteWriter<S, T> {
  final String title;
  final bool withDrawer;

  final FloatingActionButtonLocation floatingActionButtonLocation;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  final routeWriter;

  ScreenState({
    @required this.title,
    this.withDrawer = true,
    this.routeWriter = true,
    this.floatingActionButtonLocation = FloatingActionButtonLocation.endFloat,
  });

  @protected
  Widget buildFAB(BuildContext context) => null;

  @protected
  Widget bottomNavigationBar(BuildContext context) => null;

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
            title: Text(title),
            centerTitle: false,
            actions: buildAppBarActions(),
          ),
          extendBody: true,
          resizeToAvoidBottomInset: false,
          body: buildBody(context, constraints),
          floatingActionButtonLocation: floatingActionButtonLocation,
          floatingActionButton: buildFAB(context),
          bottomNavigationBar: bottomNavigationBar(context),
        );
      },
    );
  }

  List<Widget> buildAppBarActions() => <Widget>[];

  void showMessage(
    String message, {
    String action = "OK",
    VoidCallback onPressed,
    dynamic data,
  }) {
    final snackbar = SnackBar(
      duration: Duration(seconds: 2),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(message),
      ),
      action: _buildAction(action, () {
        if (onPressed != null) onPressed();
        _scaffoldKey.currentState.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
      }),
    );
    _scaffoldKey.currentState.showSnackBar(snackbar);
  }

  Widget _buildAction(String label, VoidCallback onPressed) {
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
  static RouteObserver<PageRoute> _observer;
  static get observer => _observer ??= RouteObserver<PageRoute>();

  T routeData;
  String routeName;
  bool routeWriter = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer.subscribe(this, ModalRoute.of(context));
  }

  @override
  void dispose() {
    _observer.unsubscribe(this);
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
  static RouteModel state(BuildContext context) => RouteModel.fromJson(readState(context, STATE));

  /// Write route information to PageStorage
  void writeRoute({T data, String name}) {
    if (routeWriter) {
      this.routeData = data;
      this.routeName = name ?? this.routeName;
      final route = this.routeName ?? ModalRoute.of(context)?.settings?.name;
      if (route != '/') {
        writeState(context, STATE, {
          'name': route,
          'data': data,
          // TODO: Move to IncidentBloc using hydrated_bloc and Hive (encryption support)
          'incidentId': BlocProvider.of<IncidentBloc>(context)?.current?.id,
        });
        writeAppState(PageStorage.of(context), context: context);
      }
    }
  }
}
