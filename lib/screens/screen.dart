import 'package:SarSys/widgets/app_drawer.dart';
import 'package:flutter/material.dart';

abstract class Screen<S extends ScreenState> extends StatefulWidget {
  const Screen({Key key}) : super(key: key);
  @override
  S createState();
}

abstract class ScreenState<T extends StatefulWidget> extends State<T> {
  final String title;
  final bool withDrawer;

  final FloatingActionButtonLocation floatingActionButtonLocation;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  ScreenState({
    @required this.title,
    this.withDrawer = true,
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
          ),
          extendBody: true,
          resizeToAvoidBottomInset: true,
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
